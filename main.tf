provider "aws" {
  region = var.aws_region
}

# ==============================================================================
# BASE COMPONENT NAMING RANDOMIZATION
# ==============================================================================

resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}

# ==============================================================================
# STORAGE TIER (DECOUPLED S3 BUCKETS)
# ==============================================================================

resource "aws_s3_bucket" "source" {
  bucket        = "iac-ingest-bucket-${random_string.suffix.result}"
  force_destroy = true

  tags = {
    PipelineStage = "Ingest"
    Project       = "Event-Pipeline"
  }
}

resource "aws_s3_bucket" "destination" {
  bucket        = "iac-processed-bucket-${random_string.suffix.result}"
  force_destroy = true

  tags = {
    PipelineStage = "Processed"
    Project       = "Event-Pipeline"
  }
}

# ==============================================================================
# SECURITY & IDENTITY TIER (IAM)
# ==============================================================================

resource "aws_iam_role" "event_role" {
  name = "event_driven_pipeline_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

resource "aws_iam_policy" "pipeline_policy" {
  name        = "s3_pipeline_minimum_policy"
  description = "Provides precise minimal cloud permissions for S3 bucket operations and CloudWatch logs"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject"]
        Resource = "${aws_s3_bucket.source.arn}/*"
      },
      {
        Effect   = "Allow"
        Action   = ["s3:PutObject"]
        Resource = "${aws_s3_bucket.destination.arn}/*"
      },
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "${aws_cloudwatch_log_group.lambda_logs.arn}:*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "attach_pipeline" {
  role       = aws_iam_role.event_role.name
  policy_arn = aws_iam_policy.pipeline_policy.arn
}

# ==============================================================================
# COMPUTE TIER (AWS LAMBDA)
# ==============================================================================

data "archive_file" "pipeline_zip" {
  type        = "zip"
  output_path = "${path.module}/pipeline.zip"
  
  source {
    content  = <<-EOF
      import json, boto3
      def handler(event, context):
          print("Event intercepted cleanly: " + json.dumps(event))
          return {"statusCode": 200, "body": "Automation complete"}
      EOF
    filename = "index.py"
  }
}

resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/EventDrivenPipelineProcessor"
  retention_in_days = 7
}

resource "aws_lambda_function" "pipeline_processor" {
  filename         = data.archive_file.pipeline_zip.output_path
  function_name    = "EventDrivenPipelineProcessor"
  role             = aws_iam_role.event_role.arn
  handler          = "index.handler"
  runtime          = "python3.11"
  source_code_hash = data.archive_file.pipeline_zip.output_base64sha256

  depends_on = [aws_cloudwatch_log_group.lambda_logs]
}

# ==============================================================================
# AUTOMATION LAYER (S3 EVENT NOTIFICATIONS)
# ==============================================================================

resource "aws_lambda_permission" "allow_s3" {
  statement_id  = "AllowS3Invoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.pipeline_processor.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.source.arn
}

resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket = aws_s3_bucket.source.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.pipeline_processor.arn
    events              = ["s3:ObjectCreated:*"]
  }

  depends_on = [aws_lambda_permission.allow_s3]
}
