variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "prod"
}

variable "aws_region" {
  description = "AWS region for deployment"
  type        = string
  default     = "us-east-1"
}

variable "domain_name" {
  description = "Base domain for TAK deployments (e.g., tak.nervsystems.com)"
  type        = string
}

variable "route53_zone_id" {
  description = "Route53 hosted zone ID for domain"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "Availability zones for multi-AZ deployment"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

# Customer-specific variables (used by deploy-customer.sh script)
variable "customers" {
  description = "Map of customer configurations"
  type = map(object({
    tier        = string  # starter, professional, enterprise
    max_users   = number
    nerva_mode  = string  # lite, full, custom
  }))
  default = {}
}
