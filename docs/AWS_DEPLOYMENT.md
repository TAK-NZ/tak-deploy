# AWS Deployment Guide

Complete guide for deploying NERV TAK infrastructure on AWS.

## Overview

The AWS deployment uses:
- **ECS Fargate** for container orchestration (no EC2 management)
- **RDS PostgreSQL** for each customer (isolated databases)
- **Shared ALB** with host-based routing (cost optimization)
- **ECR** for container image storage
- **Secrets Manager** for credential management
- **CloudWatch** for logging and monitoring

## Architecture

```
┌─────────────────────────────────────────────────────┐
│  Shared Infrastructure (one-time setup)             │
│  ├─ VPC (10.0.0.0/16)                               │
│  ├─ ECS Cluster                                     │
│  ├─ Application Load Balancer                       │
│  ├─ ECR Repositories (TAK Server + NERVA)           │
│  └─ Route53 / ACM Certificate                       │
└─────────────────────────────────────────────────────┘
              │
              ├─────────────────┬──────────────────┐
              ▼                 ▼                  ▼
     ┌────────────────┐  ┌─────────────┐  ┌──────────────┐
     │ Customer 1     │  │ Customer 2  │  │ Customer 3   │
     │ ECS Service    │  │ ECS Service │  │ ECS Service  │
     │ RDS Database   │  │ RDS Database│  │ RDS Database │
     │ customer1.tak..│  │ customer2...│  │ customer3... │
     └────────────────┘  └─────────────┘  └──────────────┘
```

## Prerequisites

### 1. AWS Account Setup

- AWS account with admin access
- AWS CLI configured with credentials
- Sufficient service quotas (ECS, RDS, VPC)

### 2. Domain Configuration

- Domain registered (e.g., `nervsystems.com`)
- Route53 hosted zone created
- Note the hosted zone ID

### 3. Tools Installed

```bash
# Check installations
terraform --version  # >= 1.5
aws --version        # >= 2.0
docker --version     # >= 20.0
```

### 4. TAK Server Files

- Download TAK Server from tak.gov
- Place `takserver-docker-5.x-RELEASEx.zip` in `docker/tak-server/`

## Initial Setup

### Step 1: Configure Terraform Variables

```bash
cd aws/terraform
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`:

```hcl
# AWS Configuration
environment      = "prod"
aws_region       = "us-east-1"  # Cheapest region

# Domain Configuration
domain_name      = "tak.nervsystems.com"
route53_zone_id  = "Z1234567890ABC"  # Your Route53 zone ID

# Network Configuration
vpc_cidr            = "10.0.0.0/16"
availability_zones  = ["us-east-1a", "us-east-1b"]
```

### Step 2: Build and Push Container Images

```bash
# Login to ECR (only needed once)
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin \
  <account-id>.dkr.ecr.us-east-1.amazonaws.com

# Build TAK Server image
cd ../../docker/tak-server
docker build -t nerv-tak-server:5.5 \
  --build-arg TAK_VERSION=5.5-RELEASE58 .

# Tag and push
ECR_TAK=$(aws ecr describe-repositories --repository-names nerv-tak-server \
  --query 'repositories[0].repositoryUri' --output text)
docker tag nerv-tak-server:5.5 ${ECR_TAK}:latest
docker push ${ECR_TAK}:latest

# Build NERVA image (when ready)
cd ../nerva
docker build -t nerv-nerva:latest .
ECR_NERVA=$(aws ecr describe-repositories --repository-names nerv-nerva \
  --query 'repositories[0].repositoryUri' --output text)
docker tag nerv-nerva:latest ${ECR_NERVA}:latest
docker push ${ECR_NERVA}:latest
```

### Step 3: Deploy Shared Infrastructure

```bash
cd ../../aws/terraform

# Initialize Terraform
terraform init

# Preview changes
terraform plan

# Deploy shared infrastructure
terraform apply

# Note the outputs
terraform output
```

This creates:
- VPC with public/private subnets
- ECS cluster
- Application Load Balancer
- ECR repositories
- SSL certificate (requires DNS validation)

**Important:** Wait for ACM certificate validation (can take 5-30 minutes). Check in AWS Console under Certificate Manager.

## Deploying Customers

### Quick Deploy

```bash
cd aws/scripts

# Deploy starter tier customer
./deploy-customer.sh acme starter

# Deploy professional tier customer
./deploy-customer.sh acme-premium professional

# Deploy with custom NERVA mode
./deploy-customer.sh acme-lite starter --nerva-mode lite
```

### Manual Deploy

Alternatively, edit `aws/terraform/main.tf` and add:

```hcl
module "customer_acme" {
  source = "./modules/customer-stack"

  customer_name  = "acme"
  customer_tier  = "starter"  # or professional, enterprise
  environment    = var.environment
  aws_region     = var.aws_region
  nerva_mode     = "full"

  # From shared infrastructure
  vpc_id                = module.shared_infra.vpc_id
  private_subnet_ids    = module.shared_infra.private_subnet_ids
  public_subnet_ids     = module.shared_infra.public_subnet_ids
  ecs_cluster_id        = module.shared_infra.ecs_cluster_id
  ecs_cluster_name      = module.shared_infra.ecs_cluster_name
  alb_listener_arn      = module.shared_infra.alb_listener_arn
  alb_security_group_id = module.shared_infra.alb_security_group_id
  alb_dns_name          = module.shared_infra.alb_dns_name
  alb_zone_id           = module.shared_infra.alb_zone_id
  tak_server_ecr_url    = module.shared_infra.tak_server_ecr_url
  nerva_ecr_url         = module.shared_infra.nerva_ecr_url

  domain_name         = var.domain_name
  route53_zone_id     = var.route53_zone_id
  alb_rule_priority   = 100  # Unique per customer
}
```

Then run:

```bash
terraform apply
```

## Service Tiers

### Starter ($495/mo)
- 50 users max
- 2 vCPU, 4GB RAM
- db.t4g.micro database
- 20GB storage
- 1 ECS task
- **Cost:** ~$71/month

### Professional ($1,495/mo)
- 250 users max
- 4 vCPU, 8GB RAM
- db.t4g.small database
- 50GB storage
- 2 ECS tasks (HA)
- **Cost:** ~$145/month

### Enterprise (Custom)
- 1,000+ users
- 8 vCPU, 16GB RAM
- db.t4g.medium database
- 100GB storage
- 3 ECS tasks (HA)
- **Cost:** ~$280/month

## Monitoring & Operations

### Check Service Status

```bash
# List all ECS services
aws ecs list-services --cluster tak-prod-cluster

# Describe specific customer
aws ecs describe-services \
  --cluster tak-prod-cluster \
  --services tak-acme

# Check task status
aws ecs list-tasks --cluster tak-prod-cluster \
  --service-name tak-acme
```

### View Logs

```bash
# Tail logs for a customer
aws logs tail /ecs/tak-prod \
  --follow \
  --filter-pattern acme

# View NERVA logs specifically
aws logs tail /ecs/tak-prod \
  --follow \
  --filter-pattern acme-nerva
```

### Access Admin Certificate

```bash
# Get running task ID
TASK_ID=$(aws ecs list-tasks --cluster tak-prod-cluster \
  --service-name tak-acme \
  --query 'taskArns[0]' --output text)

# Execute into container
aws ecs execute-command \
  --cluster tak-prod-cluster \
  --task $TASK_ID \
  --container tak-server \
  --interactive \
  --command "/bin/bash"

# Inside container
cat /opt/tak/certs/admin.p12 | base64
```

## Destroying Customer Infrastructure

```bash
# Using script
cd aws/scripts
./deploy-customer.sh acme starter --destroy

# Or manually
cd aws/terraform
terraform destroy -target=module.customer_acme
```

## Cost Optimization

### Current Setup (Optimized)
- **Shared ALB:** $20/month total (vs $20 per customer)
- **Fargate:** Pay per vCPU/GB used
- **RDS:** Reserved Instances for 30-40% savings
- **Data Transfer:** Minimal with Route53 + ALB
- **us-east-1:** Cheapest AWS region

### With $1000 Credits
- **14 months** of starter tier (1 customer)
- **7 months** of professional tier (1 customer)
- **3.5 months** of enterprise tier (1 customer)
- Or **10+ starter customers for 1 month** (demo/pilot)

### Reducing Costs Further
1. Use Fargate Spot (50-70% cheaper, less reliable)
2. RDS Reserved Instances (1-year commitment)
3. Reduce desired_count to 1 for all tiers
4. Use db.t4g.micro for all tiers during testing

## Troubleshooting

### ECS Task Won't Start

```bash
# Check task events
aws ecs describe-services \
  --cluster tak-prod-cluster \
  --services tak-acme \
  --query 'services[0].events[0:5]'

# Common issues:
# - Image not found: Push to ECR first
# - Insufficient memory: Increase task definition
# - Health check failing: Check CloudWatch logs
```

### Database Connection Issues

```bash
# Test database connectivity from task
aws ecs execute-command \
  --cluster tak-prod-cluster \
  --task <task-id> \
  --container tak-server \
  --interactive \
  --command "pg_isready -h <db-endpoint> -U takserver"
```

### Certificate Issues

```bash
# Check ACM certificate status
aws acm describe-certificate \
  --certificate-arn <cert-arn>

# Ensure DNS validation records exist in Route53
```

## Security Best Practices

1. **Secrets:** Never commit database passwords
2. **IAM:** Use least-privilege roles
3. **Network:** Private subnets for ECS/RDS
4. **Encryption:** Enable at-rest encryption (RDS, EBS)
5. **Updates:** Regular TAK server version updates
6. **Backups:** RDS automated backups enabled (7 days)

## Next Steps

1. Set up CloudWatch dashboards
2. Configure SNS alerts for alarms
3. Implement automated backups
4. Create customer onboarding runbook
5. Set up CI/CD pipeline for container updates

## Support

- AWS Infrastructure Issues: Check CloudWatch logs
- TAK Server Issues: Check ECS task logs
- NERVA Issues: Check NERVA container logs
- Billing: AWS Cost Explorer

---

For on-premise deployment, see [ON_PREM_DEPLOYMENT.md](ON_PREM_DEPLOYMENT.md)
