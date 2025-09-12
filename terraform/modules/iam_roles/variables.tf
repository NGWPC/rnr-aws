variable "app_name" {
  description = "The name of the application, used for resource tagging and naming."
  type        = string
}

variable "environment" {
  description = "The deployment environment (e.g., 'test', 'prod')."
  type        = string
}

variable "aws_region" {
  description = "The AWS region where resources are deployed."
  type        = string
}

variable "aws_account_id" {
  description = "The AWS account ID where resources are deployed."
  type        = string
}

variable "rabbitmq_secret_arn" {
  description = "The ARN of the RabbitMQ credentials secret in Secrets Manager."
  type        = string
}

variable "app_bucket_name" {
  description = "The name of the S3 bucket used by the application for input and output data."
  type        = string
}