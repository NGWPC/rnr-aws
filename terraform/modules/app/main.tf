# -----------------------------------------------------------------------------
# Application Module
# Defines the core compute resources: ECS Fargate Service and Lambda Functions.
# -----------------------------------------------------------------------------

# --- CloudWatch Log Groups ---
resource "aws_cloudwatch_log_group" "fargate_log_group" {
  name              = "/ecs/${var.app_name}/${var.environment}/fargate-worker"
  retention_in_days = 30

  tags = {
    Name        = "${var.app_name}-${var.environment}-fargate-log-group"
    Environment = var.environment
  }
}

resource "aws_cloudwatch_log_group" "producer_lambda_log_group" {
  name              = "/aws/lambda/${var.app_name}-${var.environment}-producer"
  retention_in_days = 30

  tags = {
    Name        = "${var.app_name}-${var.environment}-producer-lambda-log-group"
    Environment = var.environment
  }
}

resource "aws_cloudwatch_log_group" "postproc_lambda_log_group" {
  name              = "/aws/lambda/${var.app_name}-${var.environment}-post-process"
  retention_in_days = 30

  tags = {
    Name        = "${var.app_name}-${var.environment}-postproc-lambda-log-group"
    Environment = var.environment
  }
}

# --- EFS for Shared Fargate Storage ---

resource "aws_efs_file_system" "shared_data" {
  creation_token   = "${var.app_name}-${var.environment}-efs"
  performance_mode = "generalPurpose"
  throughput_mode  = "bursting"
  encrypted        = true

  tags = {
    Name        = "${var.app_name}-${var.environment}-shared-data"
    Environment = var.environment
  }
}

resource "aws_efs_mount_target" "private" {
  count           = length(var.networking.private_subnet_ids)
  file_system_id  = aws_efs_file_system.shared_data.id
  subnet_id       = element(var.networking.private_subnet_ids, count.index)
  security_groups = var.networking.efs_security_group_ids
}

resource "aws_efs_access_point" "app_access_point" {
  file_system_id = aws_efs_file_system.shared_data.id
  posix_user {
    uid = 1000
    gid = 1000
  }
  root_directory {
    path = "/data"
    creation_info {
      owner_uid   = 1000
      owner_gid   = 1000
      permissions = "755"
    }
  }
  tags = {
    Name        = "${var.app_name}-${var.environment}-access-point"
    Environment = var.environment
  }
}


# --- ECS Fargate ---

resource "aws_ecs_cluster" "main" {
  name = "${var.app_name}-${var.environment}-cluster"

  tags = {
    Name        = "${var.app_name}-${var.environment}-cluster"
    Environment = var.environment
  }
}

resource "aws_ecs_task_definition" "worker" {
  family                   = "${var.app_name}-${var.environment}-worker"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.compute_config.fargate_cpu
  memory                   = var.compute_config.fargate_memory
  execution_role_arn       = var.iam_roles.ecs_task_execution
  task_role_arn            = var.iam_roles.ecs_task

  # Shared EFS volume at the task level
  volume {
    name = "shared-data-volume"
    efs_volume_configuration {
      file_system_id     = aws_efs_file_system.shared_data.id
      transit_encryption = "ENABLED"
      authorization_config {
        access_point_id = aws_efs_access_point.app_access_point.id
      }
    }
  }

  container_definitions = jsonencode([
    {
      name      = "${var.app_name}-container"
      image     = var.compute_config.docker_image_uri
      essential = true
      # Mount the volume into the container
      mountPoints = [
        {
          sourceVolume  = "shared-data-volume"
          containerPath = "/t-route/data"
          readOnly      = false
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.fargate_log_group.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }
      environment = [
        { name = "INPUT_BUCKET_NAME", value = var.service_dependencies.gpkg_data_bucket_name },
        { name = "OUTPUT_BUCKET_NAME", value = var.service_dependencies.output_data_bucket_name },
        { name = "RABBITMQ_ENDPOINT", value = var.service_dependencies.rabbitmq_endpoint },
        { name = "RABBITMQ_SECRET_ARN", value = var.service_dependencies.rabbitmq_secret_arn }
      ]
    }
  ])

  tags = {
    Name        = "${var.app_name}-${var.environment}-worker-task"
    Environment = var.environment
  }
}

resource "aws_ecs_service" "worker" {
  name            = "${var.app_name}-${var.environment}-worker-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.worker.arn
  launch_type     = "FARGATE"
  desired_count   = var.compute_config.fargate_initial_task_count

  network_configuration {
    subnets          = var.networking.private_subnet_ids
    security_groups  = var.networking.fargate_security_group_ids
    assign_public_ip = false
  }

  depends_on = [
    aws_ecs_task_definition.worker,
    aws_efs_mount_target.private
  ]

  tags = {
    Name        = "${var.app_name}-${var.environment}-worker-service"
    Environment = var.environment
  }
}

# --- Lambda Functions ---

resource "aws_lambda_function" "producer" {
  function_name = "${var.app_name}-${var.environment}-producer"
  role          = var.iam_roles.producer_lambda

  s3_bucket = var.lambda_code.bucket_name
  s3_key    = var.lambda_code.producer_s3_key

  handler = "main.handler"
  runtime = "python3.12"
  timeout = 300

  vpc_config {
    subnet_ids         = var.networking.private_subnet_ids
    security_group_ids = var.networking.lambda_security_group_ids
  }

  environment {
    variables = {
      RABBITMQ_ENDPOINT     = var.service_dependencies.rabbitmq_endpoint
      RABBITMQ_SECRET_ARN    = var.service_dependencies.rabbitmq_secret_arn
      ELASTICACHE_ENDPOINT  = var.service_dependencies.elasticache_endpoint
    }
  }

  tags = {
    Name        = "${var.app_name}-${var.environment}-producer-lambda"
    Environment = var.environment
  }
}

resource "aws_lambda_function" "post_process" {
  function_name = "${var.app_name}-${var.environment}-post-process"
  role          = var.iam_roles.post_process_lambda

  s3_bucket = var.lambda_code.bucket_name
  s3_key    = var.lambda_code.post_process_s3_key

  handler = "main.handler"
  runtime = "python3.12"
  timeout = 300

  environment {
    variables = {
      OUTPUT_BUCKET_NAME = var.service_dependencies.output_data_bucket_name
    }
  }

  tags = {
    Name        = "${var.app_name}-${var.environment}-post-process-lambda"
    Environment = var.environment
  }
}