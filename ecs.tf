resource "aws_ecs_cluster" "cluster" {
  name = "comics-cluster"
}

data "template_file" "definition" {
  template = file("${path.module}/def.json")
  vars = {
    name   = "comics-task-def"
    image  = "${data.aws_ecr_repository.repo.repository_url}@${data.aws_ecr_image.image.id}"
    region = var.region
  }
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

resource "aws_ecs_task_definition" "task" {
  family                   = "comics-task"
  container_definitions    = data.template_file.definition.rendered
  task_role_arn            = aws_iam_role.comics_iam_for_lambda.arn
  execution_role_arn       = aws_iam_role.task_exec_role.arn
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "512"
  memory                   = "1024"
}

resource "aws_ecs_service" "service" {
  name            = "comics-service"
  task_definition = aws_ecs_task_definition.task.arn
  cluster         = aws_ecs_cluster.cluster.id
  launch_type     = "FARGATE"

  network_configuration {
    assign_public_ip = true
    subnets          = data.aws_subnet_ids.subnets.ids
    security_groups  = [aws_security_group.sec_group.id]
  }
}

resource "aws_security_group" "sec_group" {
  vpc_id = data.aws_vpc.vpc.id
  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
    description = "All outbound traffic"
  }
}


resource "aws_cloudwatch_event_target" "comics_scheduled_task" {
  rule     = aws_cloudwatch_event_rule.comics_lambda_rule.name
  arn      = aws_ecs_cluster.cluster.arn
  role_arn = aws_iam_role.comics_iam_for_lambda.arn

  ecs_target {
    task_definition_arn = aws_ecs_task_definition.task.arn
    launch_type         = "FARGATE"
    network_configuration {
      assign_public_ip = true
      subnets          = data.aws_subnet_ids.subnets.ids
      security_groups  = [aws_security_group.sec_group.id]
    }
  }
}
