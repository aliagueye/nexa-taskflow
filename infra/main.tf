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

# TP4 étape 5 - Exposition : plage autorisée à joindre l'API (réseau interne / load balancer)
variable "api_allowed_cidr" {
  description = "Plage IP autorisee a joindre l'API"
  type        = string
  default     = "10.0.0.0/16"
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
  # checkov:skip=CKV_AWS_18: Logs - journal d'acces S3 a activer avec un bucket de logs dedie, échéance 2027-02-23
  # checkov:skip=CKV2_AWS_62: Logs - notifications d'evenements sans consommateur a ce jour, échéance 2027-02-23
  # checkov:skip=CKV_AWS_21: Resilience - exports regenerables depuis la base, versioning non requis, échéance 2027-02-23
  # checkov:skip=CKV2_AWS_61: Maintenance - regles de cycle de vie a definir avec la politique de retention, échéance 2027-02-23
  # checkov:skip=CKV_AWS_144: Resilience - replication inter-regions disproportionnee pour un projet pedagogique, échéance 2027-02-23
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
  # checkov:skip=CKV_AWS_23: Gouvernance - descriptions des regles a ajouter, sans impact securite, échéance 2027-02-23

  # TP4 - SSH ouvert : règle SSH (port 22 depuis 0.0.0.0/0) supprimée

  # TP4 étape 5 - Exposition : API joignable uniquement depuis la plage autorisée
  ingress {
    from_port   = 8085
    to_port     = 8085
    protocol    = "tcp"
    cidr_blocks = [var.api_allowed_cidr]
  }

  # TP4 étape 5 - Exposition : sortie limitée au HTTPS (au lieu de tout vers partout)
  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "api" {
  # checkov:skip=CKV_AWS_126: Logs - supervision detaillee (payante) a activer avant la production, échéance 2027-02-23
  # checkov:skip=CKV_AWS_135: Performance - optimisation EBS non disponible/utile sur t3.micro, échéance 2027-02-23
  # checkov:skip=CKV2_AWS_41: Droits - role IAM a creer avec les seules permissions necessaires (SSM), échéance 2027-02-23
  ami                    = "ami-0123456789abcdef0"
  instance_type          = "t3.micro"
  vpc_security_group_ids = [aws_security_group.web.id]

  # TP4 étape 5 - Exposition : IMDSv2 obligatoire (bloque le vol d'identifiants via SSRF)
  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  root_block_device {
    volume_size = 20
    encrypted   = true # TP4 - Chiffrement du disque
  }

  tags = {
    Name = "taskflow-api"
  }
}

resource "aws_db_instance" "tasks" {
  # checkov:skip=CKV_AWS_129: Logs - export des journaux vers CloudWatch a configurer, échéance 2027-02-23
  # checkov:skip=CKV2_AWS_30: Logs - journal des requetes a activer via un parameter group, échéance 2027-02-23
  # checkov:skip=CKV_AWS_118: Logs - supervision avancee (payante) a activer avant la production, échéance 2027-02-23
  # checkov:skip=CKV_AWS_353: Logs - Performance Insights non necessaire en environnement d'analyse, échéance 2027-02-23
  # checkov:skip=CKV_AWS_161: Droits - authentification IAM non geree par l'application (connexion par mot de passe Secrets Manager), échéance 2027-02-23
  # checkov:skip=CKV_AWS_157: Resilience - multi-AZ disproportionne pour un projet pedagogique, échéance 2027-02-23
  # checkov:skip=CKV_AWS_293: Resilience - protection contre la suppression a activer avant la production, échéance 2027-02-23
  # checkov:skip=CKV_AWS_226: Maintenance - mises a jour mineures planifiees manuellement, échéance 2027-02-23
  # checkov:skip=CKV2_AWS_60: Gouvernance - copie des tags vers les snapshots sans impact securite, échéance 2027-02-23
  identifier          = "taskflow-db"
  engine              = "postgres"
  instance_class      = "db.t3.micro"
  allocated_storage   = 20
  username            = "taskflow"
  # TP4 étape 5 - Secret : mot de passe généré et stocké par AWS Secrets Manager
  manage_master_user_password = true
  publicly_accessible = false # TP4 - Base exposée
  storage_encrypted   = true  # TP4 - Chiffrement de la base
  skip_final_snapshot = true
}
