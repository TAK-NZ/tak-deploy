output "vpc_id" {
  description = "VPC ID for TAK infrastructure"
  value       = module.shared_infra.vpc_id
}

output "ecs_cluster_name" {
  description = "ECS cluster name"
  value       = module.shared_infra.ecs_cluster_name
}

output "alb_dns_name" {
  description = "Application Load Balancer DNS name"
  value       = module.shared_infra.alb_dns_name
}

output "tak_server_ecr_url" {
  description = "TAK Server ECR repository URL"
  value       = module.shared_infra.tak_server_ecr_url
}

output "nerva_ecr_url" {
  description = "NERVA ECR repository URL"
  value       = module.shared_infra.nerva_ecr_url
}

output "alb_listener_arn" {
  description = "ALB HTTPS listener ARN for customer routing"
  value       = module.shared_infra.alb_listener_arn
}
