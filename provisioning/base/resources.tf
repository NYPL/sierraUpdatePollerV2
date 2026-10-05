provider "aws" {
  region = "us-east-1"
}

locals {
  function_base_name = "Sierra${var.deployment_name}UpdatePoller"
  function_name = "${local.function_base_name}-${var.environment}"
  log_error_metric = "${local.function_base_name}LogError-${var.environment}"
}

variable "environment" {
  type        = string
  default     = "qa"
  description = "The name of the environment (qa, production). This controls the name of the lambda and the env vars loaded."

  validation {
    condition     = contains(["qa", "production"], var.environment)
    error_message = "The environment must be 'qa' or 'production'."
  }
}

variable "memory" {
  type        = number
  default     = 128
  description = "The amount of memory to allocate. Default 128M"

  validation {
    condition     = var.memory >= 128
    error_message = "The memory allocation must be at least 128."
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
  source_dir  = "../../../"
  excludes    = [".git", ".terraform", "provisioning", "sam"]
}

# Upload the zipped app to S3:
resource "aws_s3_object" "uploaded_zip" {
  bucket = "nypl-travis-builds-${var.environment}"
  key    = "${local.function_name}-dist.zip"
  acl    = "private"
  source = data.archive_file.lambda_zip.output_path
  etag   = filemd5(data.archive_file.lambda_zip.output_path)
}

# Create the lambda:
resource "aws_lambda_function" "poller_lambda" {
  description                    = "A service for polling the Sierra API for updates from the Bibs endpoint"
  function_name                  = local.function_name
  handler                        = "app.handle_event"
  memory_size                    = var.memory
  role                           = "arn:aws:iam::946183545209:role/lambda-full-access"
  runtime                        = "ruby3.4"
  reserved_concurrent_executions = 1
  timeout                        = 900

  # Location of the zipped code in S3:
  s3_bucket = aws_s3_object.uploaded_zip.bucket
  s3_key    = aws_s3_object.uploaded_zip.key

  # Trigger pulling code from S3 when the zip has changed:
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  # Load ENV vars from ./config/{environment}.env
  environment {
    variables = { for tuple in regexall("(.*?)=(.*)", file("../../../config/${var.record_env}-${var.environment}.env")) : tuple[0] => tuple[1] }
  }
}

data "aws_sns_topic" "rc_alarms" {
  name = "research-catalog-team-alarms-${var.environment}"
}

resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  alarm_name          = "${local.function_base_name}LambdaErrorAlarm-${var.environment}"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Sum"
  threshold           = 1
  alarm_description   = "Lambda function ${aws_lambda_function.poller_lambda.function_name} has invocation errors"
  alarm_actions       = [data.aws_sns_topic.rc_alarms.arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = aws_lambda_function.poller_lambda.function_name
  }
}

resource "aws_cloudwatch_log_metric_filter" "log_error_metric_filter" {
  name           = local.log_error_metric
  pattern        = "{ $.level = \"error\" }"
  log_group_name = "/aws/lambda/${aws_lambda_function.poller_lambda.function_name}"

  metric_transformation {
    name      = local.log_error_metric
    namespace = "LogMetrics"
    value     = "1"
  }
}

resource "aws_cloudwatch_metric_alarm" "log_errors" {
  alarm_name          = "${local.function_base_name}LogErrorAlarm-${var.environment}"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = local.log_error_metric
  namespace           = "LogMetrics"
  period              = 300
  statistic           = "Sum"
  threshold           = 1
  alarm_description   = "Lambda function ${aws_lambda_function.poller_lambda.function_name} has error logs"
  alarm_actions       = [data.aws_sns_topic.rc_alarms.arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = aws_lambda_function.poller_lambda.function_name
  }
}
