# -----------------------------------------------------------------------------
# Root Module - Wires all child modules together
# -----------------------------------------------------------------------------
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Team        = var.team_name
      Environment = var.environment
    }
  }
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

  app_name            = var.app_name
  environment         = var.environment
  aws_region          = var.aws_region
  aws_account_id      = data.aws_caller_identity.current.account_id
  rabbitmq_secret_arn = module.messaging.rabbitmq_secret_arn
  app_bucket_name     = var.app_bucket_name
}

module "security_groups" {
  source = "./modules/security_groups"

  app_name              = var.app_name
  environment           = var.environment
  vpc_id                = data.aws_vpc.existing.id
  rabbitmq_console_cidr = var.rabbitmq_console_cidr
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
    docker_image_uri            = var.docker_image_uri
    fargate_cpu                 = var.fargate_cpu
    fargate_memory              = var.fargate_memory
    fargate_initial_task_count  = var.fargate_initial_task_count
    fargate_min_task_count      = var.fargate_min_task_count
    fargate_max_task_count      = var.fargate_max_task_count
  }

  lambda_code = {
    bucket_name               = var.lambda_code_bucket_name
    autoscaler_s3_key         = var.lambda_autoscaler_zip_s3_key
    producer_s3_key           = var.lambda_producer_zip_s3_key
    post_process_s3_key       = var.lambda_postproc_zip_s3_key
    post_process_layer_s3_key = var.lambda_postproc_layer_zip_s3_key
  }

  networking = {
    private_subnet_ids         = data.aws_subnets.private.ids
    fargate_security_group_ids = [module.security_groups.fargate_sg_id]
    lambda_security_group_ids  = [module.security_groups.lambda_sg_id]
  }

  iam_roles = {
    ecs_task_execution  = module.iam_roles.ecs_task_execution_role_arn
    ecs_task            = module.iam_roles.ecs_task_role_arn
    autoscaler_lambda   = module.iam_roles.lambda_autoscaler_role_arn
    producer_lambda     = module.iam_roles.lambda_producer_role_arn
    post_process_lambda = module.iam_roles.lambda_postproc_role_arn
    scheduler_role      = module.iam_roles.scheduler_role_arn
  }

  service_dependencies = {
    app_bucket_name           = var.app_bucket_name
    app_output_s3_key         = var.app_output_s3_key
    hydrofabric_s3_key        = var.hydrofabric_s3_key
    postprocess_output_s3_key = var.postprocess_output_s3_key
    rabbitmq_broker_name      = module.messaging.rabbitmq_broker_name
    rabbitmq_endpoint         = module.messaging.rabbitmq_endpoint
    rabbitmq_secret_arn       = module.messaging.rabbitmq_secret_arn
    elasticache_endpoint      = module.data_stores.elasticache_redis_endpoint
  }
}

# -----------------------------------------------------------------------------
# Orchestration and Triggers
# -----------------------------------------------------------------------------

resource "aws_scheduler_schedule" "autoscaler_lambda_trigger" {
  name       = "${var.app_name}-${var.environment}-autoscaler-trigger"
  group_name = "default"

  flexible_time_window {
    mode = "OFF"
  }

  schedule_expression = "rate(2 minute)"

  target {
    arn      = module.application.lambda_autoscaler_arn
    role_arn = module.iam_roles.scheduler_role_arn
  }
}

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

resource "aws_scheduler_schedule" "postproc_lambda_trigger" {
  name       = "${var.app_name}-${var.environment}-postproc-trigger"
  group_name = "default"

  flexible_time_window {
    mode = "OFF"
  }

  schedule_expression = var.postprocess_schedule_expression

  target {
    arn      = module.application.lambda_postproc_arn
    role_arn = module.iam_roles.scheduler_role_arn
  }
}

data "aws_caller_identity" "current" {}