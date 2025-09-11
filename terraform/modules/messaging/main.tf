# -----------------------------------------------------------------------------
# Messaging Module
# Creates Amazon MQ for RabbitMQ broker.
# -----------------------------------------------------------------------------

# Use 'random' provider to generate secure password
resource "random_password" "rabbitmq" {
  length           = 20
  special          = true
  override_special = "_%@"
}

# Create secret in AWS Secrets Manager
resource "aws_secretsmanager_secret" "rabbitmq" {
  name = "${var.app_name}/${var.environment}/rabbitmq-credentials"
  tags = {
    Name        = "${var.app_name}-${var.environment}-rabbitmq-secret"
    Environment = var.environment
  }
}

# Store username and password in the secret
resource "aws_secretsmanager_secret_version" "rabbitmq" {
  secret_id = aws_secretsmanager_secret.rabbitmq.id
  secret_string = jsonencode({
    username = var.rabbitmq_username
    password = random_password.rabbitmq.result
  })
}

resource "aws_mq_broker" "rabbitmq" {
  broker_name                 = "${var.app_name}-${var.environment}-mq"
  engine_type                 = "RabbitMQ"
  engine_version              = "3.13"
  auto_minor_version_upgrade  = true
  host_instance_type          = "mq.t3.micro"
  deployment_mode             = "SINGLE_INSTANCE" # Good for dev/test. Consider "CLUSTER_MULTI_AZ" for OE/PROD?
  # For SINGLE_INSTANCE mode, we must provide one subnet.
  # We'll take the first subnet from the provided list.
  subnet_ids      = [var.private_subnet_ids[0]]
  security_groups = var.rabbitmq_security_group_ids
  publicly_accessible = false

  user {
    username = var.rabbitmq_username
    password = random_password.rabbitmq.result
  }

  logs {
    general = true
  }

  tags = {
    Name        = "${var.app_name}-${var.environment}-mq"
    Environment = var.environment
  }
}

