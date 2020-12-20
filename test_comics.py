import unittest

import boto3
import mock
from bs4 import BeautifulSoup
from moto import mock_s3, mock_sns


class ComicsTest(unittest.TestCase):
    @mock_s3
    def test_website_exists_s3(self):
        from comics import website_exists_s3

        conn = boto3.client("s3")
        conn.create_bucket(Bucket="sflomenb-comics")
        conn.put_object(Bucket="sflomenb-comics", Key="sflomenb-comics", Body="hello")
        self.assertTrue(website_exists_s3())

    @mock_s3
    def test_get_website_from_s3(self):
        from comics import get_website_from_s3

        conn = boto3.client("s3")
        conn.create_bucket(Bucket="sflomenb-comics")
        conn.put_object(Bucket="sflomenb-comics", Key="sflomenb-comics", Body="hello")
        content = get_website_from_s3()
        self.assertEqual("hello", content)

    @unittest.skip("boto/moto is not working here")
    @mock_sns
    def test_send_sms(self):
        from comics import send_sms

        conn = boto3.client("sns")
        response = send_sms("https://google.com")
        self.assertTrue("MessageId" in response)
        self.assertTrue(response["MessageId"] is not None)

    @mock.patch("comics.from_publisher")
    def test_get_comics_from_html(self, mock_from_publisher):
        from comics import get_comics_from_html

        mock_from_publisher.return_value = True

        with open("mock_comixology.html", "r") as f:
            html = f.read()
        comics, first_comic = get_comics_from_html(html, ["DC", "IDW"], "")

        self.assertTrue("Dark Nights: Death Metal (2020-)" in comics)
        self.assertTrue("Batman (2016-)" in comics)
        self.assertTrue("X-Force (2019-)" in comics)
        self.assertTrue("New Mutants (2019-)" in comics)
        self.assertTrue("Star Wars: Darth Vader (2020-)" in comics)
        self.assertTrue("Immortal Hulk (2018-)" in comics)
        self.assertTrue("Superman (2018-)" in comics)

        self.assertEqual(first_comic, "Dark Nights: Death Metal (2020-)")

    @mock.patch("comics.get_rendered_html")
    def test_is_from_publisher(self, mock_content):
        from comics import from_publisher

        with open("mock_comixology.html", "r") as f:
            html = f.read()

        with open("mock_series.html", "r") as f:
            series_html = f.read()

        mock_content.return_value = series_html

        soup = BeautifulSoup(html, "html.parser")
        tag = soup.find_all(class_="content-item")[0]

        self.assertTrue(from_publisher(tag, ["DC", "IDW"]))

    @mock_s3
    def test_upload_to_s3(self):
        from comics import upload_to_s3

        conn = boto3.client("s3")
        conn.create_bucket(Bucket="sflomenb-comics")
        self.assertFalse(
            len(
                conn.list_objects(
                    Bucket="sflomenb-comics", Prefix="sflomenb-comics"
                ).get("Contents", [])
            )
            > 0
        )
        upload_to_s3("the content")
        self.assertTrue(
            len(
                conn.list_objects(
                    Bucket="sflomenb-comics", Prefix="sflomenb-comics"
                ).get("Contents", [])
            )
            > 0
        )
        self.assertEqual(
            conn.get_object(Bucket="sflomenb-comics", Key="sflomenb-comics")
            .get("Body")
            .read()
            .decode("utf-8"),
            "the content",
        )
