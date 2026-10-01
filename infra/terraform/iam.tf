resource "aws_iam_role" "ecs_execution" {
  name = "saas-platform-dev-ecs-execution"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [{
      Effect = "Allow"

      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }

      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_execution" {
  role       = aws_iam_role.ecs_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role" "app_task" {
  name = "saas-platform-dev-app-task"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [{
      Effect = "Allow"

      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }

      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "app_sqs" {
  name = "saas-platform-dev-sqs"
  role = aws_iam_role.app_task.id

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [{
      Effect = "Allow"

      Action = [
        "sqs:ReceiveMessage",
        "sqs:DeleteMessage",
        "sqs:GetQueueAttributes"
      ]

      Resource = aws_sqs_queue.jobs.arn
    }]
  })
}

resource "aws_iam_policy" "app_uploads" {
  name = "saas-platform-dev-app-uploads"

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Action = [
          "s3:PutObject"
        ]

        Resource = "${aws_s3_bucket.uploads.arn}/uploads/*"
      }
    ]
  })
}


resource "aws_iam_role_policy_attachment" "ecs_task_uploads" {
  role       = aws_iam_role.app_task.name
  policy_arn = aws_iam_policy.app_uploads.arn
}
