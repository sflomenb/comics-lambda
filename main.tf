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
    App = "Comics"
  }
}

resource "aws_cloudwatch_event_rule" "comics_lambda_rule" {
  name                = "comics_lambda_trigger_rule"
  schedule_expression = "cron(0 14 ? * MON *)"

  tags = {
    Name = "ComicsLambdaRule"
    App = "Comics"
  }
}

