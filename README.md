# gm2j-enterprise-stack Infrastructure

Automated AWS Infrastructure following the **AWS Well-Architected Framework**.

## Architecture Overview
- **Reliability:** Multi-AZ VPC configuration.
- **Security:** Tiered subnets (Public/Private) with scoped Security Groups.
- **Cost Optimization:** Conditional NAT Gateway usage based on environment.

## Deployment
This repository uses GitHub Actions for automated Terraform execution.