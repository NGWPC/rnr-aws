# -----------------------------------------------------------------------------
# Security Groups Module
# Defines the security groups for the application components.
# -----------------------------------------------------------------------------

resource "aws_security_group" "fargate" {
  name        = "${var.app_name}-${var.environment}-fargate-sg"
  description = "Controls access for the Fargate service tasks."
  vpc_id      = var.vpc_id

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.app_name}-${var.environment}-fargate-sg"
    Environment = var.environment
  }
}

resource "aws_security_group" "lambda" {
  name        = "${var.app_name}-${var.environment}-lambda-sg"
  description = "Controls access for the VPC-enabled Lambda functions."
  vpc_id      = var.vpc_id

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.app_name}-${var.environment}-lambda-sg"
    Environment = var.environment
  }
}

resource "aws_security_group" "elasticache" {
  name        = "${var.app_name}-${var.environment}-elasticache-sg"
  description = "Controls access to the ElastiCache Redis cluster."
  vpc_id      = var.vpc_id

  # Allow inbound Redis traffic from Lambda security group
  ingress {
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [aws_security_group.lambda.id]
  }

  tags = {
    Name        = "${var.app_name}-${var.environment}-elasticache-sg"
    Environment = var.environment
  }
}

resource "aws_security_group" "rabbitmq" {
  name        = "${var.app_name}-${var.environment}-rabbitmq-sg"
  description = "Controls access to the RabbitMQ broker."
  vpc_id      = var.vpc_id

  # Allow inbound AMQPS traffic from Lambda and Fargate SGs
  ingress {
    from_port       = 5671
    to_port         = 5671
    protocol        = "tcp"
    security_groups = [aws_security_group.lambda.id, aws_security_group.fargate.id]
  }

  tags = {
    Name        = "${var.app_name}-${var.environment}-rabbitmq-sg"
    Environment = var.environment
  }
}
