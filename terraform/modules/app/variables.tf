variable "app_name" {
  description = "The name of the application."
  type        = string
}

variable "environment" {
  description = "The deployment environment (e.g., 'test', 'oe')."
  type        = string
}

variable "aws_region" {
  description = "The AWS region for deployment."
  type        = string
}

variable "compute_config" {
  description = "Configuration for the Fargate compute resources."
  type = object({
    docker_image_uri            = string
    fargate_cpu                 = number
    fargate_memory              = number
    fargate_initial_task_count  = number
    fargate_max_task_count      = number
  })
}

variable "lambda_code" {
  description = "S3 locations for the Lambda function deployment packages."
  type = object({
    bucket_name               = string
    producer_s3_key           = string
    post_process_s3_key       = string
  })
}

variable "networking" {
  description = "Networking configuration for all resources in the module."
  type = object({
    private_subnet_ids       = list(string)
    fargate_security_group_ids = list(string)
    lambda_security_group_ids  = list(string)
  })
}

variable "iam_roles" {
  description = "A collection of all required IAM role ARNs."
  type = object({
    ecs_task_execution  = string
    ecs_task            = string
    producer_lambda     = string
    post_process_lambda = string
  })
}

variable "service_dependencies" {
  description = "Endpoints and names for dependent services like S3, RabbitMQ, and ElastiCache."
  type = object({
    app_bucket_name           = string
    app_output_s3_key         = string
    postprocess_output_s3_key = string
    hydrofabric_s3_key        = string
    rabbitmq_endpoint         = string
    rabbitmq_secret_arn       = string
    elasticache_endpoint      = string
  })
}