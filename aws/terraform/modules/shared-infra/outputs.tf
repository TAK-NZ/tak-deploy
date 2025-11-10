output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "List of public subnet IDs"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "List of private subnet IDs"
  value       = aws_subnet.private[*].id
}

output "ecs_cluster_id" {
  description = "ECS Cluster ID"
  value       = aws_ecs_cluster.main.id
}

output "ecs_cluster_name" {
  description = "ECS Cluster name"
  value       = aws_ecs_cluster.main.name
}

output "alb_id" {
  description = "Application Load Balancer ID"
  value       = aws_lb.main.id
}

output "alb_arn" {
  description = "Application Load Balancer ARN"
  value       = aws_lb.main.arn
}

output "alb_dns_name" {
  description = "Application Load Balancer DNS name"
  value       = aws_lb.main.dns_name
}

output "alb_zone_id" {
  description = "Application Load Balancer Route53 zone ID"
  value       = aws_lb.main.zone_id
}

output "alb_listener_arn" {
  description = "ALB HTTPS listener ARN"
  value       = aws_lb_listener.https.arn
}

output "alb_security_group_id" {
  description = "ALB security group ID"
  value       = aws_security_group.alb.id
}

output "tak_server_ecr_url" {
  description = "TAK Server ECR repository URL"
  value       = aws_ecr_repository.tak_server.repository_url
}

output "nerva_ecr_url" {
  description = "NERVA ECR repository URL"
  value       = aws_ecr_repository.nerva.repository_url
}

output "acm_certificate_arn" {
  description = "ACM certificate ARN for wildcard domain"
  value       = aws_acm_certificate.main.arn
}

output "cloudwatch_log_group_name" {
  description = "CloudWatch log group name for ECS tasks"
  value       = aws_cloudwatch_log_group.ecs_tasks.name
}
