# PRODUCTION Environment Configuration
# SDLC Tier: Production (Critical)
# Compliance Target: SOC2-Ready
# Estimated Monthly Burn: ~$525.00

terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }
}

provider "aws" {
  region = var.aws_region
}

# 1. NETWORK (Isolation per Env & AWS Well-Architected)
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${var.project_name}-${var.environment}-vpc"
  cidr = "${var.vpc_cidr}"

  azs             = ["${var.aws_region}a", "${var.aws_region}b", "${var.aws_region}c"]
  private_subnets = [cidrsubnet(var.vpc_cidr, 8, 1), cidrsubnet(var.vpc_cidr, 8, 2), cidrsubnet(var.vpc_cidr, 8, 3)]
  public_subnets  = [cidrsubnet(var.vpc_cidr, 8, 101), cidrsubnet(var.vpc_cidr, 8, 102), cidrsubnet(var.vpc_cidr, 8, 103)]
  
  enable_nat_gateway = true
  single_nat_gateway = false
  
  enable_flow_log = true
  create_flow_log_cloudwatch_log_group = true
  create_flow_log_cloudwatch_iam_role  = true
}

# 2. SECURITY GOVERNANCE (SOC2 / AWS WAF)
resource "aws_wafv2_web_acl" "main" {
  name  = "${var.project_name}-${var.environment}-waf"
  scope = "REGIONAL"
  
  default_action { allow {} }
  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "waf${var.environment}"
    sampled_requests_enabled   = true
  }
}

# 3. COMPUTE (Auto-Scaling per Scale Requirement: high)
module "asg" {
  source = "terraform-aws-modules/autoscaling/aws"
  version = "~> 6.0"

  name = "${var.project_name}-${var.environment}-asg"
  min_size = 2
  max_size = 20
  
  vpc_zone_identifier = module.vpc.private_subnets
  instance_type       = var.instance_type
  health_check_type = "ELB"
}

# 4. DATABASE (RDS Encryption Enabled for SOC2)
module "db" {
  source = "terraform-aws-modules/rds/aws"
  version = "~> 6.0"

  identifier = "${var.project_name}-${var.environment}-db"
  engine     = "postgres"
  instance_class = var.db_instance_class
  allocated_storage = 20
  
  storage_encrypted = true
  multi_az          = true
  
  backup_retention_period = 35
  skip_final_snapshot     = false
}