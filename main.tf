variable "lambda_function_name" {
  description = "name of the lambda function in AWS"
}

variable "region" {
  description = "AWS Region"
  default     = "us-east-1"
}

variable "image_tag" {
  description = "tag for the image"
  type        = string
  default     = "latest"
}

provider "aws" {
  profile = "default"
  region  = "us-east-1"
}

data "aws_vpc" "vpc" {
  default = true
}

data "aws_subnet_ids" "subnets" {
  vpc_id = data.aws_vpc.vpc.id
}

data "aws_ecr_repository" "repo" {
  name = "comics-repo"
}

data "aws_ecr_image" "image" {
  repository_name = data.aws_ecr_repository.repo.name
  image_tag       = var.image_tag
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

resource "aws_iam_role" "comics_iam_for_lambda" {
  name = "comics_iam_lambda"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ecs-tasks.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": "AssumeEcsTasksStatement"
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

