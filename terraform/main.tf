terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.27"
    }
  }

  required_version = ">= 0.14.9"
}

provider "aws" {
  profile = "default"
  region  = "us-east-2"
}

data "aws_vpcs" "vpclist" {}

data "aws_vpc" "myvpc" {
  id = one(data.aws_vpcs.vpclist.ids)
}

data "aws_subnet_ids" "mysubnets" {
  vpc_id = data.aws_vpc.myvpc.id
}

resource "aws_security_group" "allowMe" {
  name        = "allowMe"
  description = "Lets me and inclusive members to connect"

  ingress {
    description = "all for me"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["45.30.30.70/32"]
    self        = true
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}

resource "aws_lb_target_group" "questors" {
  name     = "questors"
  port     = 3000
  protocol = "HTTP"
  target_type = "instance"
  vpc_id   = data.aws_vpc.myvpc.id
}

resource "aws_ecs_cluster" "qluster" {
  name = "qluster"
}

resource "aws_iam_role" "ecs_agent" {
  name = "ecs-agent"
  assume_role_policy = data.aws_iam_policy_document.ecs_agent.json
}

resource "aws_iam_role_policy_attachment" "ecs_agent" {
  role = aws_iam_role.ecs_agent.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

resource "aws_iam_role_policy_attachment" "ecr_ro" {
  role = aws_iam_role.ecs_agent.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_instance_profile" "ecs_agent" {
  name = "ecs_agent"
  role = aws_iam_role.ecs_agent.name
}

resource "aws_launch_configuration" "qluster" {
  name = "qluster"
  image_id = "ami-0dfa0bf531cde9048"
  instance_type = "t2.micro"
  key_name = "default"
  security_groups = [aws_security_group.allowMe.id]
  iam_instance_profile = aws_iam_instance_profile.ecs_agent.name
  user_data = "#!/bin/bash\necho ECS_CLUSTER=${aws_ecs_cluster.qluster.name} >> /etc/ecs/ecs.config"
}

data "aws_iam_policy_document" "ecs_agent" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_autoscaling_group" "qluster" {
  name = "qluster"
  launch_configuration = aws_launch_configuration.qluster.name
  min_size = 1
  max_size = 1
  vpc_zone_identifier = data.aws_subnet_ids.mysubnets.ids
}

resource "aws_ecs_task_definition" "questTask" {
  family = "questTask"
  network_mode = "host"
  container_definitions = jsonencode([
    {
      name              = "questor"
      image             = "583551776186.dkr.ecr.us-east-2.amazonaws.com/quest:latest"
      memoryReservation = 128
      portMappings = [
        {
          containerPort = 3000
          hostPort      = 3000
        }
      ]
    }
  ])
}

resource "aws_ecs_service" "questor" {
  name            = "questor"
  cluster         = aws_ecs_cluster.qluster.id
  task_definition = aws_ecs_task_definition.questTask.arn
  desired_count   = 1
  load_balancer {
    target_group_arn = aws_lb_target_group.questors.arn
    container_name   = "questor"
    container_port   = 3000
  }
  health_check_grace_period_seconds = 500
}

resource "aws_lb" "questBalancer" {
  name            = "questBalancer"
  internal        = false
  security_groups = [aws_security_group.allowMe.id]
  subnets         = data.aws_subnet_ids.mysubnets.ids
}

resource "aws_alb_listener" "questHTTPS" {
  load_balancer_arn = aws_lb.questBalancer.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = "arn:aws:iam::583551776186:server-certificate/SELF"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.questors.arn
  }
}
