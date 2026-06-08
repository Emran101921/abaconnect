# BloomOra – AWS HIPAA-eligible infrastructure (skeleton)
# Requires: terraform >= 1.5, AWS provider configured

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

variable "environment" {
  type    = string
  default = "dev"
}

variable "aws_region" {
  type    = string
  default = "us-east-1"
}

provider "aws" {
  region = var.aws_region
}

# VPC
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = {
    Name        = "abaconnect-${var.environment}"
    Environment = var.environment
    Compliance  = "HIPAA"
  }
}

# RDS PostgreSQL (encrypted)
resource "aws_db_subnet_group" "main" {
  name       = "abaconnect-db-${var.environment}"
  subnet_ids = [] # attach private subnets in production
}

resource "aws_db_instance" "postgres" {
  identifier             = "abaconnect-${var.environment}"
  engine                 = "postgres"
  engine_version         = "16"
  instance_class         = "db.t3.medium"
  allocated_storage      = 100
  storage_encrypted      = true
  kms_key_id             = aws_kms_key.main.arn
  db_name                = "abaconnect"
  username               = "abaconnect"
  manage_master_user_password = true
  vpc_security_group_ids = []
  db_subnet_group_name   = aws_db_subnet_group.main.name
  backup_retention_period = 35
  deletion_protection    = var.environment == "prod"
  skip_final_snapshot    = var.environment != "prod"

  tags = {
    Environment = var.environment
    Compliance  = "HIPAA"
  }
}

# KMS for encryption at rest
resource "aws_kms_key" "main" {
  description             = "BloomOra ${var.environment} encryption key"
  deletion_window_in_days = 30
  enable_key_rotation     = true
}

# S3 documents bucket (SSE-KMS)
resource "aws_s3_bucket" "documents" {
  bucket = "abaconnect-documents-${var.environment}"
}

resource "aws_s3_bucket_server_side_encryption_configuration" "documents" {
  bucket = aws_s3_bucket.documents.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.main.arn
    }
  }
}

resource "aws_s3_bucket_public_access_block" "documents" {
  bucket                  = aws_s3_bucket.documents.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ECS cluster placeholder
resource "aws_ecs_cluster" "api" {
  name = "abaconnect-${var.environment}"
}

output "rds_endpoint" {
  value = aws_db_instance.postgres.endpoint
}

output "documents_bucket" {
  value = aws_s3_bucket.documents.bucket
}

output "kms_key_arn" {
  value = aws_kms_key.main.arn
}
