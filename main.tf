provider "aws" {
  region = "us-east-1"
}

resource "aws_s3_bucket" "source" {
  bucket        = "iac-ingest-bucket-unique-id"
  force_destroy = true
}

resource "aws_s3_bucket" "destination" {
  bucket        = "iac-processed-bucket-unique-id"
  force_destroy = true
}

resource "aws_iam_role" "event_role" {
  name = "event_driven_pipeline_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "://amazonaws.com" }
    }]
  })
}

resource "aws_iam_policy" "pipeline_policy" {
  name = "s3_pipeline_minimum_policy"
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
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "attach_pipeline" {
  role       = aws_iam_role.event_role.name
  policy_arn = aws_iam_policy.pipeline_policy.arn
}

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

resource "aws_lambda_function" "pipeline_processor" {
  filename         = data.archive_file.pipeline_zip.output_path
  function_name    = "EventDrivenPipelineProcessor"
  role             = aws_iam_role.event_role.arn
  handler          = "index.handler"
  runtime          = "python3.11"
  source_code_hash = data.archive_file.pipeline_zip.output_base64sha256
}

resource "aws_lambda_permission" "allow_s3" {
  statement_id  = "AllowS3Invoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.pipeline_processor.function_name
  principal     = "://amazonaws.com"
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
