resource "aws_sqs_queue" "jobs" {
  name = "saas-platform-dev-jobs"

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.jobs_dlq.arn
    maxReceiveCount     = 3
  })

  tags = {
    Environment = "dev"
    Service     = "saas-platform"
  }
}

resource "aws_sqs_queue" "jobs_dlq" {
  name = "saas-platform-dev-jobs-dlq"

  message_retention_seconds = 1209600 # 14 days

  tags = {
    Environment = "dev"
    Service     = "saas-platform"
  }
}


