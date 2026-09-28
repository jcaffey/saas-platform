resource "aws_db_subnet_group" "main" {
  name = "saas-platform-dev"

  subnet_ids = [
    aws_subnet.data_a.id,
    aws_subnet.data_b.id
  ]

  tags = {
    Name        = "saas-platform-dev"
    Environment = "dev"
    Service     = "saas-platform"
  }
}

resource "aws_security_group" "database" {
  name        = "saas-platform-dev-database"
  description = "Aurora PostgreSQL access from application tasks"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name        = "saas-platform-dev-database"
    Environment = "dev"
    Service     = "saas-platform"
  }
}

resource "aws_vpc_security_group_ingress_rule" "database_from_app" {
  security_group_id = aws_security_group.database.id

  referenced_security_group_id = aws_security_group.app.id

  from_port   = 5432
  to_port     = 5432
  ip_protocol = "tcp"
}

resource "aws_rds_cluster" "main" {
  cluster_identifier = "saas-platform-dev"

  engine         = "aurora-postgresql"
  engine_version = "17.11"

  database_name   = "saasplatform"
  master_username = "postgres"

  manage_master_user_password = true

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.database.id]

  storage_encrypted = true

  backup_retention_period = 1

  skip_final_snapshot = true
  deletion_protection = false

  tags = {
    Environment = "dev"
    Service     = "saas-platform"
  }
}

resource "aws_rds_cluster_instance" "main" {
  identifier = "saas-platform-dev-1"

  cluster_identifier = aws_rds_cluster.main.id

  instance_class = "db.t4g.medium"

  engine         = aws_rds_cluster.main.engine
  engine_version = aws_rds_cluster.main.engine_version

  publicly_accessible = false
}
