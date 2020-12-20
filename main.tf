variable "lambda_code_name" {
  description = "name of file containing code for lambda, i.e., lambda.py)"
}

variable "lambda_function_name" {
  description = "name of the lambda function in AWS"
}

variable "zip_name" {
  description = "name of the zip file containing lambda code, i.e., function.zip"
}

provider "aws" {
  profile = "default"
  region  = "us-east-1"
}

resource "aws_s3_bucket" "comics_bucket" {
  bucket = "sflomenb-comics"
  acl    = "private"

  tags = {
    Name = "ComicsBucket"
  }
}

resource "aws_cloudwatch_event_rule" "comics_lambda_rule" {
  name                = "comics_lambda_trigger_rule"
  schedule_expression = "cron(0 14 * * ? *)"
  tags = {
    Name = "ComicsLambdaRule"
  }
}

resource "aws_cloudwatch_event_target" "comics_lambda_cloudwatch_target" {
  rule = aws_cloudwatch_event_rule.comics_lambda_rule.name
  arn  = aws_lambda_function.comics_lambda.arn
}

resource "aws_iam_role" "comics_iam_for_lambda" {
  name = "comics_iam_lambda"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": "AssumeLambdaStatement"
    }
  ]
}
EOF

  tags = {
    Name = "ComicsLambdaRole"
  }

}

resource "aws_iam_policy" "comics_lambda_iam_policy" {
  name = "comics_iam_policy"
  path = "/"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": ["sns:Publish"],
      "Effect": "Allow",
      "Sid": "SnsPublishStatement",
      "Resource": "*"
    },
    {
      "Action": [
        "s3:ListBucket"
      ],
      "Effect": "Allow",
      "Sid": "S3BucketStatement",
      "Resource": "${aws_s3_bucket.comics_bucket.arn}"
    },
    {
      "Action": [
        "s3:PutObject",
        "s3:GetObject"
      ],
      "Effect": "Allow",
      "Sid": "S3ObjectStatement",
      "Resource": "${aws_s3_bucket.comics_bucket.arn}/*"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "comics_lambda_iam_role_policy_attachment" {
  role       = aws_iam_role.comics_iam_for_lambda.name
  policy_arn = aws_iam_policy.comics_lambda_iam_policy.arn
}

resource "aws_iam_role_policy_attachment" "comics_lambda_cloud_watch_policy_attachment" {
  role       = aws_iam_role.comics_iam_for_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}


resource "aws_lambda_function" "comics_lambda" {
  filename      = var.zip_name
  function_name = var.lambda_function_name
  role          = aws_iam_role.comics_iam_for_lambda.arn
  handler       = "comics.lambda_handler"
  timeout       = 10

  source_code_hash = filebase64sha256("${var.zip_name}")

  runtime = "python3.8"

  environment {
    variables = {
      numbers = "+18564959075,+12158880955",
    }
  }

  depends_on = [aws_s3_bucket.comics_bucket, aws_cloudwatch_event_rule.comics_lambda_rule, aws_iam_role_policy_attachment.comics_lambda_iam_role_policy_attachment]
}

resource "aws_lambda_permission" "comics_cloudwatch_lambda_execution" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = var.lambda_function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.comics_lambda_rule.arn
  depends_on    = [aws_lambda_function.comics_lambda]
}

