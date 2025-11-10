# Customer TAK Deployment Stack
# This module creates an isolated TAK server deployment for a single customer

locals {
  # Tier-based configurations
  tier_configs = {
    starter = {
      cpu          = 2048  # 2 vCPU
      memory       = 4096  # 4 GB
      db_instance  = "db.t4g.micro"
      db_storage   = 20
      desired_count = 1
    }
    professional = {
      cpu          = 4096  # 4 vCPU
      memory       = 8192  # 8 GB
      db_instance  = "db.t4g.small"
      db_storage   = 50
      desired_count = 2
    }
    enterprise = {
      cpu          = 8192  # 8 vCPU
      memory       = 16384 # 16 GB
      db_instance  = "db.t4g.medium"
      db_storage   = 100
      desired_count = 3
    }
  }

  tier_config = local.tier_configs[var.customer_tier]
  fqdn        = "${var.customer_name}.${var.domain_name}"
}

# RDS PostgreSQL Database
resource "aws_db_subnet_group" "main" {
  name       = "tak-${var.customer_name}-db-subnet"
  subnet_ids = var.private_subnet_ids

  tags = {
    Name     = "tak-${var.customer_name}-db-subnet-group"
    Customer = var.customer_name
  }
}

resource "aws_security_group" "db" {
  name_prefix = "tak-${var.customer_name}-db-"
  description = "Security group for ${var.customer_name} TAK database"
  vpc_id      = var.vpc_id

  ingress {
    description     = "PostgreSQL from ECS tasks"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs_tasks.id]
  }

  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name     = "tak-${var.customer_name}-db-sg"
    Customer = var.customer_name
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "random_password" "db_password" {
  length  = 32
  special = true
}

resource "aws_secretsmanager_secret" "db_credentials" {
  name_prefix = "tak/${var.customer_name}/db-"
  description = "Database credentials for ${var.customer_name} TAK deployment"

  tags = {
    Customer = var.customer_name
  }
}

resource "aws_secretsmanager_secret_version" "db_credentials" {
  secret_id = aws_secretsmanager_secret.db_credentials.id
  secret_string = jsonencode({
    username = "takserver"
    password = random_password.db_password.result
    host     = aws_db_instance.main.address
    port     = 5432
    database = "cot"
  })
}

resource "aws_db_instance" "main" {
  identifier     = "tak-${var.customer_name}"
  engine         = "postgres"
  engine_version = "16.1"
  instance_class = local.tier_config.db_instance

  allocated_storage     = local.tier_config.db_storage
  max_allocated_storage = local.tier_config.db_storage * 2
  storage_type          = "gp3"
  storage_encrypted     = true

  db_name  = "cot"
  username = "takserver"
  password = random_password.db_password.result

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.db.id]

  backup_retention_period = 7
  backup_window          = "03:00-04:00"
  maintenance_window     = "mon:04:00-mon:05:00"

  skip_final_snapshot       = var.environment != "prod"
  final_snapshot_identifier = var.environment == "prod" ? "tak-${var.customer_name}-final-${formatdate("YYYY-MM-DD-hhmm", timestamp())}" : null

  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]

  tags = {
    Name     = "tak-${var.customer_name}-db"
    Customer = var.customer_name
    Tier     = var.customer_tier
  }
}

# ECS Task Security Group
resource "aws_security_group" "ecs_tasks" {
  name_prefix = "tak-${var.customer_name}-ecs-"
  description = "Security group for ${var.customer_name} ECS tasks"
  vpc_id      = var.vpc_id

  ingress {
    description     = "HTTPS from ALB"
    from_port       = 8443
    to_port         = 8443
    protocol        = "tcp"
    security_groups = [var.alb_security_group_id]
  }

  ingress {
    description     = "TAK API from ALB"
    from_port       = 8089
    to_port         = 8089
    protocol        = "tcp"
    security_groups = [var.alb_security_group_id]
  }

  ingress {
    description     = "TAK Streaming from ALB"
    from_port       = 9000
    to_port         = 9001
    protocol        = "tcp"
    security_groups = [var.alb_security_group_id]
  }

  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name     = "tak-${var.customer_name}-ecs-sg"
    Customer = var.customer_name
  }

  lifecycle {
    create_before_destroy = true
  }
}

# ECS Task Execution Role
resource "aws_iam_role" "ecs_task_execution" {
  name_prefix = "tak-${var.customer_name}-exec-"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
    }]
  })

  tags = {
    Customer = var.customer_name
  }
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy" "ecs_task_execution_secrets" {
  name_prefix = "secrets-access-"
  role        = aws_iam_role.ecs_task_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "secretsmanager:GetSecretValue"
      ]
      Resource = [
        aws_secretsmanager_secret.db_credentials.arn
      ]
    }]
  })
}

# ECS Task Role (for application permissions)
resource "aws_iam_role" "ecs_task" {
  name_prefix = "tak-${var.customer_name}-task-"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
    }]
  })

  tags = {
    Customer = var.customer_name
  }
}

# ECS Task Definition
resource "aws_ecs_task_definition" "main" {
  family                   = "tak-${var.customer_name}"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = local.tier_config.cpu
  memory                   = local.tier_config.memory
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([
    {
      name      = "tak-server"
      image     = "${var.tak_server_ecr_url}:latest"
      essential = true

      portMappings = [
        { containerPort = 8089, protocol = "tcp" },
        { containerPort = 8443, protocol = "tcp" },
        { containerPort = 8444, protocol = "tcp" },
        { containerPort = 8446, protocol = "tcp" },
        { containerPort = 9000, protocol = "tcp" },
        { containerPort = 9001, protocol = "tcp" }
      ]

      environment = [
        { name = "DB_HOST", value = aws_db_instance.main.address },
        { name = "DB_PORT", value = "5432" },
        { name = "DB_NAME", value = "cot" },
        { name = "DB_USER", value = "takserver" },
        { name = "TAK_HOSTNAME", value = local.fqdn },
        { name = "TAK_CERT_ORG", value = var.customer_name },
        { name = "TAK_CERT_OU", value = "TAK Operations" },
        { name = "TAK_CERT_CITY", value = "Singapore" },
        { name = "TAK_CERT_STATE", value = "Singapore" },
        { name = "TAK_CERT_COUNTRY", value = "SG" }
      ]

      secrets = [
        {
          name      = "DB_PASSWORD"
          valueFrom = "${aws_secretsmanager_secret.db_credentials.arn}:password::"
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/tak-${var.environment}"
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = var.customer_name
        }
      }

      healthCheck = {
        command     = ["CMD-SHELL", "curl -f -k https://localhost:8443/Marti/api/version || exit 1"]
        interval    = 30
        timeout     = 10
        retries     = 3
        startPeriod = 120
      }
    },
    {
      name      = "nerva"
      image     = "${var.nerva_ecr_url}:latest"
      essential = false

      environment = [
        { name = "TAK_HOST", value = "localhost" },
        { name = "TAK_PORT", value = "8089" },
        { name = "TAK_API_URL", value = "https://localhost:8443" },
        { name = "DB_HOST", value = aws_db_instance.main.address },
        { name = "DB_PORT", value = "5432" },
        { name = "DB_NAME", value = "cot" },
        { name = "DB_USER", value = "takserver" },
        { name = "NERVA_MODE", value = var.nerva_mode }
      ]

      secrets = [
        {
          name      = "DB_PASSWORD"
          valueFrom = "${aws_secretsmanager_secret.db_credentials.arn}:password::"
        }
      ]

      dependsOn = [
        {
          containerName = "tak-server"
          condition     = "HEALTHY"
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/tak-${var.environment}"
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "${var.customer_name}-nerva"
        }
      }
    }
  ])

  tags = {
    Customer = var.customer_name
    Tier     = var.customer_tier
  }
}

# ECS Service
resource "aws_ecs_service" "main" {
  name            = "tak-${var.customer_name}"
  cluster         = var.ecs_cluster_id
  task_definition = aws_ecs_task_definition.main.arn
  desired_count   = local.tier_config.desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.main.arn
    container_name   = "tak-server"
    container_port   = 8443
  }

  deployment_configuration {
    maximum_percent         = 200
    minimum_healthy_percent = 100
  }

  depends_on = [
    aws_lb_listener_rule.main,
    aws_db_instance.main
  ]

  tags = {
    Customer = var.customer_name
    Tier     = var.customer_tier
  }
}

# Target Group for this customer
resource "aws_lb_target_group" "main" {
  name        = "tak-${var.customer_name}"
  port        = 8443
  protocol    = "HTTPS"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    path                = "/Marti/api/version"
    protocol            = "HTTPS"
    matcher             = "200"
  }

  deregistration_delay = 30

  tags = {
    Customer = var.customer_name
  }
}

# ALB Listener Rule (host-based routing)
resource "aws_lb_listener_rule" "main" {
  listener_arn = var.alb_listener_arn
  priority     = var.alb_rule_priority

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main.arn
  }

  condition {
    host_header {
      values = [local.fqdn]
    }
  }

  tags = {
    Customer = var.customer_name
  }
}

# Route53 DNS Record
resource "aws_route53_record" "main" {
  zone_id = var.route53_zone_id
  name    = local.fqdn
  type    = "A"

  alias {
    name                   = var.alb_dns_name
    zone_id                = var.alb_zone_id
    evaluate_target_health = true
  }
}

# CloudWatch Alarms
resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  alarm_name          = "tak-${var.customer_name}-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "CPU utilization is too high for ${var.customer_name}"

  dimensions = {
    ClusterName = var.ecs_cluster_name
    ServiceName = aws_ecs_service.main.name
  }

  tags = {
    Customer = var.customer_name
  }
}

resource "aws_cloudwatch_metric_alarm" "memory_high" {
  alarm_name          = "tak-${var.customer_name}-memory-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "MemoryUtilization"
  namespace           = "AWS/ECS"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "Memory utilization is too high for ${var.customer_name}"

  dimensions = {
    ClusterName = var.ecs_cluster_name
    ServiceName = aws_ecs_service.main.name
  }

  tags = {
    Customer = var.customer_name
  }
}
