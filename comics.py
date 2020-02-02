#/usr/bin/env python3

import boto3
import os
import requests
import difflib
import datetime
import sys
from bs4 import BeautifulSoup
import logging

#BASE_URL = 'https://www.readdc.com/search/series?search={}-&seriesSearchDetailList_pg={}'
BASE_URL = 'https://www.readdc.com/search/series'
BUCKET = 'sflomenb-comics'
OBJECT = 'sflomenb-comics'
YEARS = [datetime.datetime.now().strftime('%Y')]
if 'years' in os.environ:
    YEARS = os.environ.get('years').split(',')
NUMBERS = os.environ.get('numbers')
if NUMBERS:
    NUMBERS = NUMBERS.split(',')

s3_client = boto3.client('s3')
sns_client = boto3.client('sns')

def website_exists_s3():
    objs = s3_client.list_objects(Bucket=BUCKET, Prefix=OBJECT)
    logging.info('objs: %s', objs)
    return len(objs.get('Contents', [])) > 0

def get_website_from_s3():
    return s3_client.get_object(Bucket=BUCKET, Key=OBJECT).get('Body').read().decode('utf-8')

def get_current_website_content(url, params):
    req = requests.get(url, params)
    req.raise_for_status()
    return req.text

def get_comics_from_html(website_html):
    soup = BeautifulSoup(website_html, 'html.parser')
    return set([tag.contents[0] for tag in soup.find_all('h5')])

def send_sms(text):
    logging.debug('text: %s', text)
    responses = []
    for number in NUMBERS:
        response = sns_client.publish(
            PhoneNumber=number,
            Message='AWS Comics Lambda: changes found: \n\n' + text
        )
        responses.append(response)
    return responses

def upload_to_s3(content):
    logging.debug('content: %s', content)
    s3_client.put_object(Bucket=BUCKET, Key=OBJECT, Body=content)

def get_website_changes():
    root = logging.getLogger()
    if 'verbose' in os.environ:
        log_level = logging.DEBUG
    else:
        log_level = logging.INFO
    root.setLevel(log_level)

    handler = logging.StreamHandler(sys.stdout)
    handler.setLevel(log_level)

    formatter = logging.Formatter('%(levelname)s - %(funcName)s - %(message)s')
    handler.setFormatter(formatter)
    root.handlers = [handler]

    comics = set()
    comics_list_s3 = set()
    s3_comics = set()
    if website_exists_s3():
        website_content_from_s3 = get_website_from_s3()
        s3_comics.update(website_content_from_s3.split('\n'))
    logging.debug('s3_comics: %s', s3_comics)
    for year in YEARS:
        last_comics = set()
        index = 0
        while True:
            current_content = get_current_website_content(BASE_URL, {'search': str(year) + '-', 'seriesSearchDetailList_pg': index})
            current_comics = get_comics_from_html(current_content)
            logging.debug('current_comics: %s', current_comics)
            if current_comics == last_comics:
                logging.debug(f'breaking loop for {year} with index {index}')
                break
            last_comics = current_comics
            comics.update(current_comics)
            logging.debug('last_comics: %s', last_comics)
            index+=1
    if comics != s3_comics:
        logging.debug('comics: %s', comics)
        logging.debug('s3_comics: %s', s3_comics)
        logging.debug("Found changes, uploading to S3")
        difference = comics - s3_comics
        send_sms('\n'.join(difference))
        upload_to_s3('\n'.join(comics))

def lambda_handler(event, context):
    get_website_changes()

if __name__ == '__main__':
    lambda_handler(None, None)
