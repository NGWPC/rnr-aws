output "elasticache_redis_endpoint" {
  description = "The primary endpoint address for the ElastiCache Redis cluster."
  value       = aws_elasticache_cluster.redis.cache_nodes[0].address
}
