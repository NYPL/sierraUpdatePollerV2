provider "aws" {
  region = "us-east-1"
}

variable "environment" {
  type = string
  default = "qa"
  description = "The name of the environment (qa, production). This controls the name of the lambda and the env vars loaded."

  validation {
    condition = contains(["qa", "production"], var.environment)
    error_message = "The environment must be 'qa' or 'production'."
  }
}

variable "deployment_name" {
  type = string
  description = "The name of the deployment. This controls the name of the lambda and the s3 bucket."
}

variable "record_env" {
  type = string
  description = "The name of the env file to use for setting environment variables"
}

# Package the app as a zip:
data "archive_file" "lambda_zip" {
  type        = "zip"
  output_path = "${path.module}/dist.zip"
  source_dir  = "../../"
  excludes    = [".git", ".terraform", "provisioning", "sam"]
}

# Upload the zipped app to S3:
resource "aws_s3_object" "uploaded_zip" {
  bucket = "sierra-poller-state-${var.environment}"
  key    = "Sierra${var.deployment_name}UpdatePoller-${var.environment}-dist.zip"
  acl    = "private"
  source = data.archive_file.lambda_zip.output_path
  etag   = filemd5(data.archive_file.lambda_zip.output_path)
}

# Create the lambda:
resource "aws_lambda_function" "poller_lambda" {
  description   = "A service for polling the Sierra API for updates from the Bibs endpoint"
  function_name = "Sierra${var.deployment_name}UpdatePoller-${var.environment}"
  handler       = "app.handle_event"
  memory_size   = 128
  role          = "arn:aws:iam::946183545209:role/lambda-full-access"
  runtime       = "ruby2.7"
  timeout       = 60

  # Location of the zipped code in S3:
  s3_bucket     = aws_s3_object.uploaded_zip.bucket
  s3_key        = aws_s3_object.uploaded_zip.key

  # Trigger pulling code from S3 when the zip has changed:
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  # Load ENV vars from ./config/{environment}.env
  environment {
    variables = { for tuple in regexall("(.*?)=(.*)", file("../../config/${var.record_env}-${var.environment}.env")) : tuple[0] => tuple[1] }
  }
}

  # resource "aws_cloudwatch_event_rule" "every_five_minutes" {
  #   name = "every-five-minutes"
  #   description = "Fires every five minutes"
  #   schedule_expression = "rate(5 minutes)"
  # }

  # resource "aws_cloudwatch_event_target" "run_poller_every_five_minutes" {
  #     rule = "${aws_cloudwatch_event_rule.every_five_minutes.name}"
  #     target_id = "Sierra${var.deployment_name}UpdatePoller-${var.environment}"
  #     arn = "${aws_lambda_function.poller_lambda.arn}"
  # }

  # resource "aws_lambda_permission" "allow_cloudwatch_to_call_pollers" {
  #     statement_id = "AllowExecutionFromCloudWatch"
  #     action = "lambda:InvokeFunction"
  #     function_name = "Sierra${var.deployment_name}UpdatePoller-${var.environment}"
  #     principal = "events.amazonaws.com"
  #     source_arn = "${aws_cloudwatch_event_rule.every_five_minutes.arn}"
  # }
