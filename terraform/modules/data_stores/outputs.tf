output "gpkg_data_bucket_name" {
  description = "The name of the S3 bucket for GPKG domain data."
  value       = aws_s3_bucket.gpkg_data_bucket.id
}

output "gpkg_data_bucket_arn" {
  description = "The ARN of the S3 bucket for GPKG domain data."
  value       = aws_s3_bucket.gpkg_data_bucket.arn
}

output "output_data_bucket_name" {
  description = "The name of the S3 bucket for output data."
  value       = aws_s3_bucket.output_data_bucket.id
}

output "output_data_bucket_arn" {
  description = "The ARN of the S3 bucket for output data."
  value       = aws_s3_bucket.output_data_bucket.arn
}

output "elasticache_redis_endpoint" {
  description = "The primary endpoint address for the ElastiCache Redis cluster."
  value       = aws_elasticache_cluster.redis.cache_nodes[0].address
}

