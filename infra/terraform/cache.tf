resource "aws_elasticache_subnet_group" "main" {
  name = "saas-platform-dev"

  subnet_ids = [
    aws_subnet.data_a.id,
    aws_subnet.data_b.id
  ]
}

resource "aws_security_group" "redis" {
  name        = "saas-platform-dev-redis"
  description = "Redis access from application tasks"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name        = "saas-platform-dev-redis"
    Environment = "dev"
    Service     = "saas-platform"
  }
}

resource "aws_vpc_security_group_ingress_rule" "redis_from_app" {
  security_group_id = aws_security_group.redis.id

  referenced_security_group_id = aws_security_group.app.id

  from_port   = 6379
  to_port     = 6379
  ip_protocol = "tcp"
}

resource "aws_elasticache_replication_group" "main" {
  replication_group_id = "saas-platform-dev"
  description          = "Redis for SaaS platform dev"

  engine         = "redis"
  engine_version = "7.1"
  node_type      = "cache.t4g.micro"

  num_cache_clusters = 1

  subnet_group_name  = aws_elasticache_subnet_group.main.name
  security_group_ids = [aws_security_group.redis.id]

  at_rest_encryption_enabled = true
  transit_encryption_enabled = true

  tags = {
    Environment = "dev"
    Service     = "saas-platform"
  }
}
