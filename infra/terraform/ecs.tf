resource "aws_ecs_cluster" "main" {
  name = "saas-platform-dev"

  tags = {
    Environment = "dev"
    Service     = "saas-platform"
  }
}

resource "aws_ecr_repository" "app" {
  name = "saas-platform-dev-app"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Environment = "dev"
    Service     = "saas-platform"
  }
}

resource "aws_cloudwatch_log_group" "app" {
  name              = "/ecs/saas-platform-dev"
  retention_in_days = 7

  tags = {
    Environment = "dev"
    Service     = "saas-platform"
  }
}

resource "aws_ecs_task_definition" "app" {
  family                   = "saas-platform-dev"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"

  cpu    = 256
  memory = 512

  execution_role_arn = aws_iam_role.ecs_execution.arn
  task_role_arn      = aws_iam_role.app_task.arn

  container_definitions = jsonencode([
    {
      name      = "app"
      image     = "${aws_ecr_repository.app.repository_url}:${var.image_tag}"
      essential = true


      portMappings = [
        {
          containerPort = 4000
          protocol      = "tcp"
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"

        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.app.name
          "awslogs-region"        = "us-east-1"
          "awslogs-stream-prefix" = "app"
        }
      }
    }
  ])

  tags = {
    Environment = "dev"
    Service     = "saas-platform"
  }
}

resource "aws_security_group" "app" {
  name        = "saas-platform-dev-app"
  description = "Security group for application ECS tasks"
  vpc_id      = aws_vpc.main.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "saas-platform-dev-app"
    Environment = "dev"
    Service     = "saas-platform"
  }
}

resource "aws_ecs_service" "app" {
  name            = "saas-platform-dev-app"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = 1

  launch_type = "FARGATE"

  network_configuration {
    subnets = [
      aws_subnet.app_a.id,
      aws_subnet.app_b.id
    ]

    security_groups = [
      aws_security_group.app.id
    ]

    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.app.arn
    container_name   = "app"
    container_port   = 4000
  }
}

