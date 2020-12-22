resource "aws_iam_role" "comics_iam_task_role" {
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
    },
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "events.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": "AssumeCloudWatchStatement"
    }
  ]
}
EOF

  tags = {
    Name = "ComicsRole"
    App = "Comics"
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
    },
    {
      "Effect": "Allow",
      "Action": [
        "ecs:RunTask"
      ],
      "Resource": [
        "*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": "iam:PassRole",
      "Resource": [
        "*"
      ],
      "Condition": {
        "StringLike": {
          "iam:PassedToService": "ecs-tasks.amazonaws.com"
        }
      }
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "comics_lambda_iam_role_policy_attachment" {
  role       = aws_iam_role.comics_iam_task_role.name
  policy_arn = aws_iam_policy.comics_lambda_iam_policy.arn
}

data "aws_iam_role" "ecs_service_execution_role" {
  name = "AWSServiceRoleForECS"
}

data "aws_iam_policy" "ecs_task_execution_policy" {
  arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role" "task_exec_role" {
  name               = "comics_iam_task_exec_role"
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
    App = "Comics"
  }
}

resource "aws_iam_policy" "comics_task_exec_role_policy" {
  name = "comics_task_exec_role_policy"
  path = "/"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "logs:CreateLogGroup"
      ],
      "Effect": "Allow",
      "Sid": "CreateLogGroup",
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "ecs:RunTask"
      ],
      "Resource": [
        "*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": "iam:PassRole",
      "Resource": [
        "*"
      ],
      "Condition": {
        "StringLike": {
          "iam:PassedToService": "ecs-tasks.amazonaws.com"
        }
      }
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "comics_task_esc_managed_role_attachment" {
  role       = aws_iam_role.task_exec_role.name
  policy_arn = data.aws_iam_policy.ecs_task_execution_policy.arn
}

resource "aws_iam_role_policy_attachment" "comics_task_esc_role_attachment" {
  role       = aws_iam_role.task_exec_role.name
  policy_arn = aws_iam_policy.comics_task_exec_role_policy.arn
}

