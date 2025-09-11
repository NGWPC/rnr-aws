# -----------------------------------------------------------------------------
# Data Stores Module
# Creates S3 buckets and the ElastiCache Redis cluster.
# -----------------------------------------------------------------------------

# --- S3 Buckets ---

# Bucket for GPKG Domain Data (Input)
resource "aws_s3_bucket" "gpkg_data_bucket" {
  bucket = "${var.app_name}-${var.environment}-gpkg-data"

  tags = {
    Name        = "${var.app_name}-${var.environment}-gpkg-data"
    Environment = var.environment
  }
}

resource "aws_s3_bucket_public_access_block" "gpkg_data_bucket_pab" {
  bucket = aws_s3_bucket.gpkg_data_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Bucket for Output Data
resource "aws_s3_bucket" "output_data_bucket" {
  bucket = "${var.app_name}-${var.environment}-output-data"

  tags = {
    Name        = "${var.app_name}-${var.environment}-output-data"
    Environment = var.environment
  }
}

resource "aws_s3_bucket_public_access_block" "output_data_bucket_pab" {
  bucket = aws_s3_bucket.output_data_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}


# --- ElastiCache for Redis ---

resource "aws_elasticache_subnet_group" "default" {
  name       = "${var.app_name}-${var.environment}-redis-subnet-group"
  subnet_ids = var.private_subnet_ids

  tags = {
    Name        = "${var.app_name}-${var.environment}-redis-subnet-group"
    Environment = var.environment
  }
}

resource "aws_elasticache_cluster" "redis" {
  cluster_id           = "${var.app_name}-${var.environment}-redis"
  engine               = "redis"
  node_type            = "cache.t3.small"
  num_cache_nodes      = 1
  parameter_group_name = "default.redis7"
  engine_version       = "7.0"
  port                 = 6379

  subnet_group_name    = aws_elasticache_subnet_group.default.name
  security_group_ids   = var.elasticache_security_group_ids

  tags = {
    Name        = "${var.app_name}-${var.environment}-redis"
    Environment = var.environment
  }
}

