import unittest

import boto3
import mock
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

    @mock.patch("comics.requests")
    def test_get_current_content(self, mock_requests):
        from comics import get_current_website_content

        content = get_current_website_content("https://google.com", {})
        mock_requests.get.assert_called_with("https://google.com", {})

    @unittest.skip("boto/moto is not working here")
    @mock_sns
    def test_send_sms(self):
        from comics import send_sms

        conn = boto3.client("sns")
        response = send_sms("https://google.com")
        self.assertTrue("MessageId" in response)
        self.assertTrue(response["MessageId"] is not None)

    def test_get_comics_from_html(self):
        from comics import get_comics_from_html

        with open("mock_html.html", "r") as f:
            html = f.read()
        comics = get_comics_from_html(html)

        self.assertTrue("Doomsday Clock (2017-)" in comics)
        self.assertTrue("Batman (2016-)" in comics)
        self.assertTrue("Justice League (2018-)" in comics)
        self.assertTrue("Batman/Superman (2019-)" in comics)
        self.assertTrue("Legion of Super-Heroes (2019-)" in comics)
        self.assertTrue("Justice League: Hell Arisen (2019-)" in comics)
        self.assertTrue("Flash Forward (2019-)" in comics)

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
