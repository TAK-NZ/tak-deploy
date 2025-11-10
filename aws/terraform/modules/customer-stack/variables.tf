variable "customer_name" {
  description = "Customer name (used for resource naming)"
  type        = string
}

variable "customer_tier" {
  description = "Service tier: starter, professional, enterprise"
  type        = string
  validation {
    condition     = contains(["starter", "professional", "enterprise"], var.customer_tier)
    error_message = "Tier must be starter, professional, or enterprise"
  }
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID from shared infrastructure"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for ECS tasks and RDS"
  type        = list(string)
}

variable "public_subnet_ids" {
  description = "Public subnet IDs (if needed)"
  type        = list(string)
}

variable "ecs_cluster_id" {
  description = "ECS cluster ID from shared infrastructure"
  type        = string
}

variable "ecs_cluster_name" {
  description = "ECS cluster name"
  type        = string
}

variable "alb_listener_arn" {
  description = "ALB HTTPS listener ARN for routing rules"
  type        = string
}

variable "alb_security_group_id" {
  description = "ALB security group ID"
  type        = string
}

variable "alb_dns_name" {
  description = "ALB DNS name for Route53 alias"
  type        = string
}

variable "alb_zone_id" {
  description = "ALB Route53 zone ID for alias"
  type        = string
}

variable "tak_server_ecr_url" {
  description = "TAK Server ECR repository URL"
  type        = string
}

variable "nerva_ecr_url" {
  description = "NERVA ECR repository URL"
  type        = string
}

variable "domain_name" {
  description = "Base domain for TAK deployment"
  type        = string
}

variable "route53_zone_id" {
  description = "Route53 hosted zone ID"
  type        = string
}

variable "alb_rule_priority" {
  description = "Priority for ALB listener rule (must be unique per customer)"
  type        = number
  default     = 100
}

variable "nerva_mode" {
  description = "NERVA operational mode: lite, full, custom"
  type        = string
  default     = "full"
  validation {
    condition     = contains(["lite", "full", "custom"], var.nerva_mode)
    error_message = "NERVA mode must be lite, full, or custom"
  }
}
