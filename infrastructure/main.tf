terraform {
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }
}

provider "aws" {
  region = "us-east-1"
}

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"
  name = "gm2j-enterprise-stack-vpc"
  cidr = "10.0.0.0/16"
  azs = ["us-east-1a", "us-east-1b"]
  private_subnets = ["10.0.2.0/24", "10.0.20.0/24"]
  public_subnets  = ["10.0.1.0/24", "10.0.11.0/24"]
  enable_nat_gateway = true
}

resource "aws_instance" "app" {
  count = 2
  ami = "ami-0c55b159cbfafe1f0"
  instance_type = "t3.medium"
  subnet_id = module.vpc.private_subnets[0]
  tags = { Name = "gm2j-enterprise-stack-app", Env = "production" }
}
