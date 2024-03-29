provider "aws" {
  region = "us-east-1"
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
  key    = "Sierra${var.deployment_name}UpdatePoller-${var.environment}-dist.zip"
  acl    = "private"
  source = data.archive_file.lambda_zip.output_path
  etag   = filemd5(data.archive_file.lambda_zip.output_path)
}

# Create the lambda:
resource "aws_lambda_function" "poller_lambda" {
  description                    = "A service for polling the Sierra API for updates from the Bibs endpoint"
  function_name                  = "Sierra${var.deployment_name}UpdatePoller-${var.environment}"
  handler                        = "app.handle_event"
  memory_size                    = var.memory
  role                           = "arn:aws:iam::946183545209:role/lambda-full-access"
  runtime                        = "ruby2.7"
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
