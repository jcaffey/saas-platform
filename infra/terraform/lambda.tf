resource "aws_iam_role" "upload_processor" {
  name = "saas-platform-dev-upload-processor"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [{
      Effect = "Allow"

      Principal = {
        Service = "lambda.amazonaws.com"
      }

      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "upload_processor_logs" {
  role       = aws_iam_role.upload_processor.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "upload_processor_sqs" {
  name = "saas-platform-dev-upload-processor-sqs"
  role = aws_iam_role.upload_processor.id

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [{
      Effect = "Allow"

      Action = [
        "sqs:SendMessage"
      ]

      Resource = aws_sqs_queue.jobs.arn
    }]
  })
}

data "archive_file" "upload_processor" {
  type        = "zip"
  source_file = "${path.module}/../../lambda/upload_processor.py"
  output_path = "${path.module}/../../lambda/upload_processor.zip"
}

resource "aws_lambda_function" "upload_processor" {
  function_name = "saas-platform-dev-upload-processor"

  filename         = data.archive_file.upload_processor.output_path
  source_code_hash = data.archive_file.upload_processor.output_base64sha256

  role    = aws_iam_role.upload_processor.arn
  handler = "upload_processor.handler"
  runtime = "python3.13"

  environment {
    variables = {
      QUEUE_URL = aws_sqs_queue.jobs.url
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.upload_processor_logs,
    aws_iam_role_policy.upload_processor_sqs,
  ]
}

resource "aws_lambda_permission" "allow_s3_uploads" {
  statement_id  = "AllowS3Uploads"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.upload_processor.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.uploads.arn
}

resource "aws_s3_bucket_notification" "uploads" {
  bucket = aws_s3_bucket.uploads.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.upload_processor.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "uploads/"
  }

  depends_on = [
    aws_lambda_permission.allow_s3_uploads
  ]
}
