#!/usr/bin/env python3

import datetime
import logging
import os
import sys
from typing import Dict, List, Optional, Set, Tuple

import boto3
from bs4 import BeautifulSoup
from bs4.element import Tag
from requests_html import HTMLSession

BASE_URL = "https://www.comixology.com/search/series"
BUCKET = "sflomenb-comics"
OBJECT = "sflomenb-comics"
YEARS = [datetime.datetime.now().strftime("%Y")]
if "years" in os.environ:
    YEARS = os.environ.get("years").split(",")
NUMBERS = os.environ.get("numbers")
if NUMBERS:
    NUMBERS = NUMBERS.split(",")
PUBLISHERS = os.environ.get("publishers", "DC").split(",")
REGION = os.environ.get("region", "us-east-1")

SESSION = None

s3_client = boto3.client("s3", region_name=REGION)
sns_client = boto3.client("sns", region_name=REGION)


def website_exists_s3():
    objs = s3_client.list_objects(Bucket=BUCKET, Prefix=OBJECT)
    logging.info("objs: %s", objs)
    return len(objs.get("Contents", [])) > 0


def get_website_from_s3():
    return (
        s3_client.get_object(Bucket=BUCKET, Key=OBJECT)
        .get("Body")
        .read()
        .decode("utf-8")
    )


def get_rendered_html(
    url: str, params: Optional[Dict[str, int]] = None
) -> BeautifulSoup:
    logging.debug("url: %s", str(url))
    logging.debug("params: %s", str(params))
    global SESSION
    if not SESSION:
        SESSION = HTMLSession()

    resp = SESSION.get(url, params=params)

    resp.html.render()

    return resp.html.html


def from_publisher(tag: Tag, publishers: List[str]) -> bool:
    url = tag.a["href"]

    soup = BeautifulSoup(get_rendered_html(url), "html.parser")

    return soup.find_all(class_="publisher")[0].h3.text.strip() in publishers


def get_comics_from_html(
    website_html: str, publishers: List[str], previous_comic: str
) -> Tuple[Set[str], str]:
    soup = BeautifulSoup(website_html, "html.parser")
    tags = soup.find_all(class_="content-item")
    names = set()
    first_comic = tags[0].figure.h5.contents[0]
    if first_comic != previous_comic:
        names.update(
            [
                tag.figure.h5.contents[0]
                for tag in tags
                if from_publisher(tag, publishers)
            ]
        )
    logging.debug("names: %s", str(names))
    return names, first_comic


def send_sms(text):
    logging.debug("text: %s", text)
    responses = []
    for number in NUMBERS:
        response = sns_client.publish(
            PhoneNumber=number, Message=f"AWS Comics Lambda: changes found: \n\n{text}"
        )
        responses.append(response)
    return responses


def upload_to_s3(content):
    logging.debug("content: %s", content)
    s3_client.put_object(Bucket=BUCKET, Key=OBJECT, Body=content)


def get_website_changes():
    root = logging.getLogger()
    if "verbose" in os.environ:
        log_level = logging.DEBUG
    else:
        log_level = logging.INFO
    root.setLevel(log_level)

    handler = logging.StreamHandler(sys.stdout)
    handler.setLevel(log_level)

    formatter = logging.Formatter("%(levelname)s - %(funcName)s - %(message)s")
    handler.setFormatter(formatter)
    root.handlers = [handler]

    comics = set()
    s3_comics = set()
    if website_exists_s3():
        website_content_from_s3 = get_website_from_s3()
        s3_comics.update(website_content_from_s3.split("\n"))
    logging.debug("s3_comics: %s", s3_comics)
    for year in YEARS:
        index = 1
        previous_comic = ""
        current_comic = "yes"
        while previous_comic != current_comic:
            previous_comic = current_comic
            current_content = get_rendered_html(
                BASE_URL,
                {"search": str(year) + "-", "seriesSearchDetailList_pg": index},
            )
            current_comics, current_comic = get_comics_from_html(
                current_content, PUBLISHERS, previous_comic
            )
            logging.info("current_comics: %s", current_comics)
            comics.update(current_comics)
            index += 1
    difference = comics - s3_comics
    logging.debug("difference: %s", str(difference))
    if difference:
        logging.debug("Found changes, uploading to S3")
        send_sms("\n".join(difference))
        upload_to_s3("\n".join(comics))


def lambda_handler(event, context):
    get_website_changes()


if __name__ == "__main__":
    lambda_handler(None, None)
