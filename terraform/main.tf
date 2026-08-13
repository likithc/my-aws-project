# Terraform configuration block
terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# AWS Provider configuration
provider "aws" {
  region = var.aws_region
}

# Elastic Container Registry (ECR) Repository
resource "aws_ecr_repository" "app_repo" {
  name                 = var.repository_name
  image_tag_mutability = "MUTABLE"

  # Automatically scan images for security vulnerabilities on push
  image_scanning_configuration {
    scan_on_push = true
  }

  # Encryption at rest using default AWS managed key
  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = {
    Environment = var.environment
    Project     = "aws-demo-app"
    ManagedBy   = "Terraform"
  }
}

# ECR Lifecycle Policy (Single consolidated policy)
resource "aws_ecr_lifecycle_policy" "app_repo_policy" {
  repository = aws_ecr_repository.app_repo.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Expire untagged images older than 14 days"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 14
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 2
        description  = "Keep last 5 tagged images, expire older ones"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["latest", "v"]
          countType     = "imageCountMoreThan"
          countNumber   = 5
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

# ---------------------------------------------------------
# NEW ECS FARGATE INFRASTRUCTURE ADDED BELOW
# ---------------------------------------------------------

# Create the ECS Cluster
resource "aws_ecs_cluster" "app_cluster" {
  name = "my-aws-demo-app-cluster"
}

# Create a CloudWatch Log Group for your container logs
resource "aws_cloudwatch_log_group" "app_logs" {
  name              = "/ecs/my-aws-demo-app"
  retention_in_days = 7
}

# Fetch default VPC and subnets (needed for Fargate network configuration)
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# Security group to allow web traffic to the container
resource "aws_security_group" "ecs_sg" {
  name        = "my-aws-demo-app-sg"
  description = "Allow inbound traffic on port 8080"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# A dummy task definition just to get the service created initially.
# GitHub Actions will overwrite this with your real image immediately after.
resource "aws_ecs_task_definition" "dummy" {
  family                   = "my-aws-demo-app-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  container_definitions = jsonencode([
    {
      name      = "app"
      image     = "nginx:latest" # Dummy image
      essential = true
    }
  ])
}

# Create the ECS Service (Fargate)
resource "aws_ecs_service" "app_service" {
  name        = "my-aws-demo-app-service"
  cluster     = aws_ecs_cluster.app_cluster.id
  launch_type = "FARGATE"

  task_definition = aws_ecs_task_definition.dummy.arn
  desired_count   = 1

  network_configuration {
    subnets          = data.aws_subnets.default.ids
    security_groups  = [aws_security_group.ecs_sg.id] # <--- Added this line!
    assign_public_ip = true
  }
}

# ---------------------------------------------------------
# IAM ROLE FOR ECS TASK EXECUTION
# ---------------------------------------------------------

resource "aws_iam_role" "ecs_task_execution_role" {
  name = "ecsTaskExecutionRole"

  # Trust policy: Allows ECS tasks to assume this role
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

# Attach the standard AWS managed policy for pulling ECR images and CloudWatch logs
resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}
