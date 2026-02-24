# gm2j-secure-web-app - High Security Web Stack

Infrastructure as Code (IaC) baseline following the **AWS Well-Architected Framework**.

## Architecture Components
- **Network:** VPC with isolated Public, Private, and Database tiers.
- **Compute:** Auto Scaling Group (EC2) behind an Application Load Balancer.
- **Security:** ALB protected by AWS WAF v2 (Common Rule Set).
- **Database:** RDS PostgreSQL with encrypted storage in private subnets.
- **Storage:** Private S3 bucket with AES256 encryption & versioning.
- **Audit:** CloudTrail enabled for cross-region audit logging.
- **Monitoring:** CloudWatch metrics enabled for WAF and ALB.