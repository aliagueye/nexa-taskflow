# Infrastructure de TaskFlow (AWS) — volontairement mal configurée.
# Ce code n'a pas vocation à être appliqué : il sert uniquement à l'analyse.

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "eu-west-3"
}

data "aws_caller_identity" "current" {}

# TP4 - Chiffrement : clé KMS dédiée, avec rotation automatique
resource "aws_kms_key" "taskflow" {
  description         = "Chiffrement des donnees TaskFlow (S3)"
  enable_key_rotation = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "AdministrationParLeCompte"
      Effect    = "Allow"
      Principal = { AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root" }
      Action    = "kms:*"
      Resource  = "*"
    }]
  })
}

resource "aws_s3_bucket" "exports" {
  bucket = "taskflow-exports-demo"
}

# TP4 - Bucket public : ACL "public-read" supprimée, tout accès public bloqué
resource "aws_s3_bucket_public_access_block" "exports" {
  bucket                  = aws_s3_bucket.exports.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# TP4 - Chiffrement : chiffrement par défaut du bucket avec la clé KMS
resource "aws_s3_bucket_server_side_encryption_configuration" "exports" {
  bucket = aws_s3_bucket.exports.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.taskflow.arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_security_group" "web" {
  name        = "taskflow-web"
  description = "Acces a l'API TaskFlow"

  # TP4 - SSH ouvert : règle SSH (port 22 depuis 0.0.0.0/0) supprimée

  ingress {
    from_port   = 8085
    to_port     = 8085
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "api" {
  ami                    = "ami-0123456789abcdef0"
  instance_type          = "t3.micro"
  vpc_security_group_ids = [aws_security_group.web.id]

  root_block_device {
    volume_size = 20
    encrypted   = true # TP4 - Chiffrement du disque
  }

  tags = {
    Name = "taskflow-api"
  }
}

resource "aws_db_instance" "tasks" {
  identifier          = "taskflow-db"
  engine              = "postgres"
  instance_class      = "db.t3.micro"
  allocated_storage   = 20
  username            = "taskflow"
  password            = "ChangeMe123!"
  publicly_accessible = false # TP4 - Base exposée
  storage_encrypted   = true  # TP4 - Chiffrement de la base
  skip_final_snapshot = true
}
