# -----------------------------------------------------------------------------
# IAM Roles and Policies Module
# -----------------------------------------------------------------------------

# --- Trust Policies / Assume Role Policies ---
data "aws_iam_policy_document" "assume_role_ecs_tasks" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "assume_role_lambda" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "assume_role_scheduler" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["scheduler.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "read_rabbitmq_secret" {
  statement {
    sid    = "AllowReadingRabbitMQCredentials"
    effect = "Allow"
    actions = [
      "secretsmanager:GetSecretValue",
    ]
    resources = [
      var.rabbitmq_secret_arn,
    ]
  }
}

resource "aws_iam_policy" "read_rabbitmq_secret" {
  name        = "${var.app_name}-${var.environment}-read-rabbitmq-secret-policy"
  description = "Allows reading the RabbitMQ secret"
  policy      = data.aws_iam_policy_document.read_rabbitmq_secret.json
}

# -----------------------------------------------------------------------------
# ECS Task Execution Role (For the Fargate Agent)
# This role is used by the Fargate agent to pull container images and write logs.
# -----------------------------------------------------------------------------
resource "aws_iam_role" "ecs_task_execution_role" {
  name               = "${var.app_name}-${var.environment}-ecs-execution-role"
  assume_role_policy = data.aws_iam_policy_document.assume_role_ecs_tasks.json
  tags = {
    Name        = "${var.app_name}-${var.environment}-ecs-execution-role"
    Environment = var.environment
  }
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# -----------------------------------------------------------------------------
# ECS Task Role (For the Application Container)
# This role grants permissions to the application running inside the container.
# -----------------------------------------------------------------------------
resource "aws_iam_role" "ecs_task_role" {
  name               = "${var.app_name}-${var.environment}-ecs-task-role"
  assume_role_policy = data.aws_iam_policy_document.assume_role_ecs_tasks.json
  tags = {
    Name        = "${var.app_name}-${var.environment}-ecs-task-role"
    Environment = var.environment
  }
}

resource "aws_iam_policy" "ecs_task_policy" {
  name        = "${var.app_name}-${var.environment}-ecs-task-policy"
  description = "Policy for the T-Route ECS task to access S3 buckets."

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = [
            "s3:GetObject",
            "s3:ListBucket"
        ],
        Resource = [
            var.input_data_bucket_arn,
            "${var.input_data_bucket_arn}/*"
        ]
      },
      {
        Effect   = "Allow",
        Action   = [
            "s3:PutObject",
            "s3:DeleteObject"
        ],
        Resource = [
            var.output_data_bucket_arn,
            "${var.output_data_bucket_arn}/*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_policy_attachment" {
  role       = aws_iam_role.ecs_task_role.name
  policy_arn = aws_iam_policy.ecs_task_policy.arn
}

resource "aws_iam_role_policy_attachment" "ecs_task_read_secret" {
  role       = aws_iam_role.ecs_task_role.name
  policy_arn = aws_iam_policy.read_rabbitmq_secret.arn
}

# -----------------------------------------------------------------------------
# Data Producer Lambda Role
# Needs permission to create network interfaces in the VPC.
# -----------------------------------------------------------------------------
resource "aws_iam_role" "lambda_producer_role" {
  name               = "${var.app_name}-${var.environment}-lambda-producer-role"
  assume_role_policy = data.aws_iam_policy_document.assume_role_lambda.json
  tags = {
    Name        = "${var.app_name}-${var.environment}-lambda-producer-role"
    Environment = var.environment
  }
}

resource "aws_iam_role_policy_attachment" "lambda_producer_vpc_access" {
  role       = aws_iam_role.lambda_producer_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_role_policy_attachment" "lambda_producer_read_secret" {
  role       = aws_iam_role.lambda_producer_role.name
  policy_arn = aws_iam_policy.read_rabbitmq_secret.arn
}

# -----------------------------------------------------------------------------
# Post-Processing Lambda Role
# Needs permission to write logs to CloudWatch.
# -----------------------------------------------------------------------------
resource "aws_iam_role" "lambda_postproc_role" {
  name               = "${var.app_name}-${var.environment}-lambda-postproc-role"
  assume_role_policy = data.aws_iam_policy_document.assume_role_lambda.json
  tags = {
    Name        = "${var.app_name}-${var.environment}-lambda-postproc-role"
    Environment = var.environment
  }
}

resource "aws_iam_role_policy_attachment" "lambda_postproc_basic_execution" {
  role       = aws_iam_role.lambda_postproc_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# -----------------------------------------------------------------------------
# EventBridge Scheduler Role
# Needs permission to invoke the producer Lambda function.
# -----------------------------------------------------------------------------
resource "aws_iam_role" "scheduler_role" {
  name               = "${var.app_name}-${var.environment}-scheduler-role"
  assume_role_policy = data.aws_iam_policy_document.assume_role_scheduler.json
  tags = {
    Name        = "${var.app_name}-${var.environment}-scheduler-role"
    Environment = var.environment
  }
}

resource "aws_iam_policy" "scheduler_policy" {
  name        = "${var.app_name}-${var.environment}-scheduler-invoke-lambda-policy"
  description = "Allows EventBridge Scheduler to invoke the producer Lambda."

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = "lambda:InvokeFunction",
        # This ARN is constructed to specifically target the producer lambda created in the application module.
        # This follows the principle of least privilege.
        Resource = "arn:aws:lambda:${var.aws_region}:${var.aws_account_id}:function:${var.app_name}-${var.environment}-producer-lambda"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "scheduler_policy_attachment" {
  role       = aws_iam_role.scheduler_role.name
  policy_arn = aws_iam_policy.scheduler_policy.arn
}

