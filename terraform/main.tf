# -----------------------------------------------------------------------------
# Root Module - Wires all child modules together
# -----------------------------------------------------------------------------
provider "aws" {
  region = var.aws_region
}

# Data sources to get existing network infrastructure details
data "aws_vpc" "existing" {
  filter {
    name   = "tag:Name"
    values = [var.vpc_name]
  }
}

data "aws_subnets" "private" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.existing.id]
  }

  tags = {
    Name = var.subnet_name_pattern
  }
}

# -----------------------------------------------------------------------------
# Child Module Definitions
# -----------------------------------------------------------------------------

module "iam_roles" {
  source = "./modules/iam_roles"

  app_name       = var.app_name
  environment    = var.environment
  aws_region     = var.aws_region
  aws_account_id = data.aws_caller_identity.current.account_id

  rabbitmq_secret_arn = module.messaging.rabbitmq_secret_arn

  input_data_bucket_arn  = module.data_stores.gpkg_data_bucket_arn
  output_data_bucket_arn = module.data_stores.output_data_bucket_arn
}

module "security_groups" {
  source = "./modules/security_groups"

  app_name    = var.app_name
  environment = var.environment
  vpc_id      = data.aws_vpc.existing.id
}

module "data_stores" {
  source = "./modules/data_stores"

  app_name           = var.app_name
  environment        = var.environment
  private_subnet_ids = data.aws_subnets.private.ids

  elasticache_security_group_ids = [module.security_groups.elasticache_sg_id]
}

module "messaging" {
  source = "./modules/messaging"

  app_name           = var.app_name
  environment        = var.environment
  private_subnet_ids = data.aws_subnets.private.ids
  rabbitmq_username  = "admin"

  rabbitmq_security_group_ids = [module.security_groups.rabbitmq_sg_id]
}

# -----------------------------------------------------------------------------
# Application Module - UPDATED
# -----------------------------------------------------------------------------

module "application" {
  source = "./modules/app"

  app_name    = var.app_name
  environment = var.environment
  aws_region  = var.aws_region

  compute_config = {
    docker_image_uri       = var.docker_image_uri
    fargate_cpu            = var.fargate_cpu
    fargate_memory         = var.fargate_memory
    fargate_initial_task_count = var.fargate_initial_task_count
  }

  lambda_code = {
    bucket_name         = var.lambda_code_bucket_name
    producer_s3_key     = var.lambda_producer_zip_s3_key
    post_process_s3_key = var.lambda_postproc_zip_s3_key
  }

  networking = {
    private_subnet_ids         = data.aws_subnets.private.ids
    fargate_security_group_ids = [module.security_groups.fargate_sg_id]
    lambda_security_group_ids  = [module.security_groups.lambda_sg_id]
    efs_security_group_ids     = [module.security_groups.efs_sg_id]
  }

  iam_roles = {
    ecs_task_execution  = module.iam_roles.ecs_task_execution_role_arn
    ecs_task            = module.iam_roles.ecs_task_role_arn
    producer_lambda     = module.iam_roles.lambda_producer_role_arn
    post_process_lambda = module.iam_roles.lambda_postproc_role_arn
  }

  service_dependencies = {
    gpkg_data_bucket_name   = module.data_stores.gpkg_data_bucket_name
    output_data_bucket_name = module.data_stores.output_data_bucket_name
    rabbitmq_endpoint       = module.messaging.rabbitmq_endpoint
    rabbitmq_secret_arn     = module.messaging.rabbitmq_secret_arn
    elasticache_endpoint    = module.data_stores.elasticache_redis_endpoint
  }
}

# -----------------------------------------------------------------------------
# Orchestration and Triggers
# -----------------------------------------------------------------------------

resource "aws_scheduler_schedule" "producer_lambda_trigger" {
  name       = "${var.app_name}-${var.environment}-producer-trigger"
  group_name = "default"

  flexible_time_window {
    mode = "OFF"
  }

  schedule_expression = var.producer_schedule_expression

  target {
    arn      = module.application.lambda_producer_arn
    role_arn = module.iam_roles.scheduler_role_arn
  }
}

resource "aws_s3_bucket_notification" "post_process_trigger" {
  bucket = module.data_stores.output_data_bucket_name

  lambda_function {
    lambda_function_arn = module.application.lambda_postproc_arn
    events              = ["s3:ObjectCreated:*"]
  }
}

resource "aws_lambda_permission" "allow_s3_to_call_lambda" {
  statement_id  = "AllowS3ToCallLambda"
  action        = "lambda:InvokeFunction"
  function_name = module.application.lambda_postproc_function_name
  principal     = "s3.amazonaws.com"
  source_arn    = module.data_stores.output_data_bucket_arn
}

data "aws_caller_identity" "current" {}