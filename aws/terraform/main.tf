terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Optional: Uncomment for remote state
  # backend "s3" {
  #   bucket = "nerv-tak-terraform-state"
  #   key    = "tak-infrastructure/terraform.tfstate"
  #   region = "us-east-1"
  # }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "NERV TAK Infrastructure"
      ManagedBy   = "Terraform"
      Environment = var.environment
    }
  }
}

# Shared infrastructure (VPC, ECS cluster, ALB, ECR)
module "shared_infra" {
  source = "./modules/shared-infra"

  environment          = var.environment
  aws_region          = var.aws_region
  domain_name         = var.domain_name
  vpc_cidr            = var.vpc_cidr
  availability_zones  = var.availability_zones
}

# Example: Deploy a customer stack
# Uncomment and customize for each customer deployment
# module "customer_demo" {
#   source = "./modules/customer-stack"
#
#   customer_name       = "demo"
#   customer_tier       = "starter"
#   environment         = var.environment
#   aws_region         = var.aws_region
#
#   # From shared infrastructure
#   vpc_id              = module.shared_infra.vpc_id
#   private_subnet_ids  = module.shared_infra.private_subnet_ids
#   public_subnet_ids   = module.shared_infra.public_subnet_ids
#   ecs_cluster_id      = module.shared_infra.ecs_cluster_id
#   alb_listener_arn    = module.shared_infra.alb_listener_arn
#   alb_security_group_id = module.shared_infra.alb_security_group_id
#   tak_server_ecr_url  = module.shared_infra.tak_server_ecr_url
#   nerva_ecr_url       = module.shared_infra.nerva_ecr_url
#
#   domain_name         = var.domain_name
#   route53_zone_id     = var.route53_zone_id
# }
