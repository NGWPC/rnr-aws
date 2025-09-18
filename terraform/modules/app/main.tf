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

  container_definitions = jsonencode([
    {
      name      = "${var.app_name}-container"
      image     = var.compute_config.docker_image_uri
      essential = true    
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.fargate_log_group.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }
      environment = [
        { name = "RABBITMQ_ENDPOINT", value = var.service_dependencies.rabbitmq_endpoint },
        { name = "RABBITMQ_HOST", value = var.service_dependencies.rabbitmq_endpoint },
        { name = "RABBITMQ_SECRET_ARN", value = var.service_dependencies.rabbitmq_secret_arn },
        { name = "APP_BUCKET_NAME", value = var.service_dependencies.app_bucket_name },
        { name = "APP_OUTPUT_S3_KEY", value = var.service_dependencies.app_output_s3_key },
        { name = "HYDROFABRIC_S3_KEY", value = var.service_dependencies.hydrofabric_s3_key }
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
    aws_ecs_task_definition.worker
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

  handler = "producer_lambda.lambda_handler"
  runtime = "python3.12"
  timeout = 300

  vpc_config {
    subnet_ids         = var.networking.private_subnet_ids
    security_group_ids = var.networking.lambda_security_group_ids
  }

  environment {
    variables = {
      RABBITMQ_ENDPOINT   = var.service_dependencies.rabbitmq_endpoint
      RABBITMQ_SECRET_ARN = var.service_dependencies.rabbitmq_secret_arn
      REDIS_HOST          = var.service_dependencies.elasticache_endpoint
    }
  }

  tags = {
    Name        = "${var.app_name}-${var.environment}-producer-lambda"
    Environment = var.environment
  }
}

# --- Post Process Lambda Dependencies Layer and Function ---

resource "aws_lambda_layer_version" "post_process_deps" {
  layer_name = "${var.app_name}-${var.environment}-post-process-dependencies"

  # Use the same bucket as the function code
  s3_bucket = var.lambda_code.bucket_name 
  s3_key    = var.lambda_code.post_process_layer_s3_key

  compatible_runtimes = ["python3.12"]
  description         = "Shared dependencies for the post-processing Lambda"
}

resource "aws_lambda_function" "post_process" {
  function_name = "${var.app_name}-${var.environment}-post-process"
  role          = var.iam_roles.post_process_lambda

  s3_bucket = var.lambda_code.bucket_name
  s3_key    = var.lambda_code.post_process_s3_key

  handler = "post_process_lambda.lambda_handler"
  runtime = "python3.12"
  timeout = 300
  memory_size = 256

  layers = [aws_lambda_layer_version.post_process_deps.arn]

  # Increased ephemeral storage to handle large parquet file during post-processing
  ephemeral_storage {
    size = 2048
  }

  environment {
    variables = {
      APP_BUCKET_NAME = var.service_dependencies.app_bucket_name
      APP_OUTPUT_S3_KEY = var.service_dependencies.app_output_s3_key
      POSTPROCESS_OUTPUT_S3_KEY = var.service_dependencies.postprocess_output_s3_key
      HYDROFABRIC_S3_KEY = var.service_dependencies.hydrofabric_s3_key
    }
  }

  tags = {
    Name        = "${var.app_name}-${var.environment}-post-process-lambda"
    Environment = var.environment
  }
}