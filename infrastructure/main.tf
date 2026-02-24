# Enterprise-Grade Secure Web Stack
# Framework: AWS Well-Architected (Security, Reliability, Performance)

terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }
}

provider "aws" {
  region = var.aws_region
  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      Provisioner = "GM2J-Orchestrator"
    }
  }
}

# 1. NETWORK LAYER (Multi-AZ VPC)
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${var.project_name}-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["${var.aws_region}a", "${var.aws_region}b", "${var.aws_region}c"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
  database_subnets = ["10.0.201.0/24", "10.0.202.0/24"]

  enable_nat_gateway = true
  single_nat_gateway = var.environment != "production" ? true : false
}

# 2. SECURITY LAYER (WAFv2)
resource "aws_wafv2_web_acl" "main" {
  name        = "${var.project_name}-waf"
  scope       = "REGIONAL"
  description = "WAF for ALB protection"
  
  default_action { allow {} }

  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 1
    override_action { none {} }
    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "WAFCommonRules"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "mainWAF"
    sampled_requests_enabled   = true
  }
}

# 3. COMPUTE LAYER (ALB + ASG)
module "alb" {
  source  = "terraform-aws-modules/alb/aws"
  version = "~> 8.0"

  name               = "${var.project_name}-alb"
  vpc_id             = module.vpc.vpc_id
  subnets            = module.vpc.public_subnets
  security_groups    = [aws_security_group.alb.id]
  
  target_groups = [
    {
      name_prefix      = "app-"
      backend_protocol = "HTTP"
      backend_port     = 80
      target_type      = "instance"
    }
  ]
}

resource "aws_wafv2_web_acl_association" "alb" {
  resource_arn = module.alb.lb_arn
  web_acl_arn  = aws_wafv2_web_acl.main.arn
}

module "asg" {
  source  = "terraform-aws-modules/autoscaling/aws"
  version = "~> 6.0"

  name = "${var.project_name}-asg"

  min_size            = 2
  max_size            = 5
  desired_capacity    = 2
  vpc_zone_identifier = module.vpc.private_subnets
  target_group_arns   = module.alb.target_group_arns

  image_id      = data.aws_ami.amazon_linux_2.id
  instance_type = "t3.medium"
  
  security_groups = [aws_security_group.app.id]
}

# 4. DATA LAYER (RDS PostgreSQL)
module "db" {
  source  = "terraform-aws-modules/rds/aws"
  version = "~> 6.0"

  identifier = "${var.project_name}-db"

  engine               = "postgres"
  engine_version       = "15.3"
  family               = "postgres15"
  instance_class       = "db.t3.medium"
  allocated_storage    = 20
  storage_encrypted    = true

  db_name  = "webappdb"
  username = "dbadmin"
  port     = "5432"

  vpc_security_group_ids = [aws_security_group.db.id]
  db_subnet_group_name   = module.vpc.database_subnet_group_name
  
  maintenance_window      = "Mon:00:00-Mon:03:00"
  backup_window           = "03:00-06:00"
  backup_retention_period = 7
  skip_final_snapshot     = true
}

# 5. STORAGE LAYER (Secure S3)
module "s3_bucket" {
  source = "terraform-aws-modules/s3-bucket/aws"
  version = "~> 3.0"

  bucket = "${var.project_name}-assets-${random_id.suffix.hex}"
  acl    = "private"

  control_object_ownership = true
  object_ownership         = "ObjectWriter"

  versioning = { enabled = true }
  
  server_side_encryption_configuration = {
    rule = {
      apply_server_side_encryption_by_default = {
        sse_algorithm = "AES256"
      }
    }
  }
}

# 6. OBSERVABILITY (CloudTrail & CloudWatch)
resource "aws_cloudtrail" "main" {
  name                          = "${var.project_name}-trail"
  s3_bucket_name                = module.s3_bucket.s3_bucket_id
  include_global_service_events = true
  is_multi_region_trail         = true
  enable_log_file_validation    = true
}

# SECURITY GROUPS
resource "aws_security_group" "alb" {
  name   = "${var.project_name}-alb-sg"
  vpc_id = module.vpc.vpc_id
  ingress { protocol = "tcp"; from_port = 80; to_port = 80; cidr_blocks = ["0.0.0.0/0"] }
  egress { protocol = "-1"; from_port = 0; to_port = 0; cidr_blocks = ["0.0.0.0/0"] }
}

resource "aws_security_group" "app" {
  name   = "${var.project_name}-app-sg"
  vpc_id = module.vpc.vpc_id
  ingress { protocol = "tcp"; from_port = 80; to_port = 80; security_groups = [aws_security_group.alb.id] }
  egress { protocol = "-1"; from_port = 0; to_port = 0; cidr_blocks = ["0.0.0.0/0"] }
}

resource "aws_security_group" "db" {
  name   = "${var.project_name}-db-sg"
  vpc_id = module.vpc.vpc_id
  ingress { protocol = "tcp"; from_port = 5432; to_port = 5432; security_groups = [aws_security_group.app.id] }
}

# DATA SOURCES & HELPERS
data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]
  filter { name = "name"; values = ["amzn2-ami-hvm-*-x86_64-gp2"] }
}

resource "random_id" "suffix" {
  byte_length = 4
}