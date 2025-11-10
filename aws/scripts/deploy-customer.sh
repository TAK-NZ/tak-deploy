#!/bin/bash
set -e

# NERV Systems - Customer TAK Deployment Script
# Deploys an isolated TAK server instance for a customer

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="$SCRIPT_DIR/../terraform"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Help function
show_help() {
    echo "NERV TAK Customer Deployment Script"
    echo ""
    echo "Usage: $0 <customer-name> <tier> [options]"
    echo ""
    echo "Arguments:"
    echo "  customer-name    Customer identifier (lowercase, alphanumeric)"
    echo "  tier             Service tier: starter, professional, enterprise"
    echo ""
    echo "Options:"
    echo "  --nerva-mode MODE    NERVA mode: lite, full, custom (default: full)"
    echo "  --destroy            Destroy customer infrastructure"
    echo "  --help               Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 acme starter"
    echo "  $0 acme professional --nerva-mode lite"
    echo "  $0 acme starter --destroy"
    echo ""
}

# Parse arguments
if [ $# -lt 1 ]; then
    show_help
    exit 1
fi

CUSTOMER_NAME=""
TIER=""
NERVA_MODE="full"
DESTROY=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --help|-h)
            show_help
            exit 0
            ;;
        --destroy)
            DESTROY=true
            shift
            ;;
        --nerva-mode)
            NERVA_MODE="$2"
            shift 2
            ;;
        *)
            if [ -z "$CUSTOMER_NAME" ]; then
                CUSTOMER_NAME="$1"
            elif [ -z "$TIER" ]; then
                TIER="$1"
            else
                echo -e "${RED}❌ Unknown argument: $1${NC}"
                exit 1
            fi
            shift
            ;;
    esac
done

# Validate inputs
if [ -z "$CUSTOMER_NAME" ]; then
    echo -e "${RED}❌ Customer name is required${NC}"
    show_help
    exit 1
fi

if [ "$DESTROY" = false ] && [ -z "$TIER" ]; then
    echo -e "${RED}❌ Tier is required for deployment${NC}"
    show_help
    exit 1
fi

# Validate tier
if [ "$DESTROY" = false ] && ! [[ "$TIER" =~ ^(starter|professional|enterprise)$ ]]; then
    echo -e "${RED}❌ Invalid tier. Must be: starter, professional, or enterprise${NC}"
    exit 1
fi

# Validate customer name format
if ! [[ "$CUSTOMER_NAME" =~ ^[a-z0-9-]+$ ]]; then
    echo -e "${RED}❌ Customer name must be lowercase alphanumeric with hyphens only${NC}"
    exit 1
fi

# Validate NERVA mode
if ! [[ "$NERVA_MODE" =~ ^(lite|full|custom)$ ]]; then
    echo -e "${RED}❌ Invalid NERVA mode. Must be: lite, full, or custom${NC}"
    exit 1
fi

# Change to terraform directory
cd "$TERRAFORM_DIR"

# Check if terraform is initialized
if [ ! -d ".terraform" ]; then
    echo -e "${YELLOW}⚠️  Terraform not initialized. Running terraform init...${NC}"
    terraform init
fi

# Get next available ALB rule priority
get_next_priority() {
    # Start at 100, increment for each customer
    local priority=100
    while terraform state list | grep -q "module.customer_${CUSTOMER_NAME}.aws_lb_listener_rule.main"; do
        priority=$((priority + 1))
    done
    echo $priority
}

if [ "$DESTROY" = true ]; then
    echo -e "${YELLOW}🗑️  Destroying TAK infrastructure for: ${CUSTOMER_NAME}${NC}"
    echo ""

    # Remove module from main.tf if it exists
    MODULE_BLOCK=$(grep -n "module \"customer_${CUSTOMER_NAME}\"" main.tf || true)
    if [ -n "$MODULE_BLOCK" ]; then
        echo -e "${YELLOW}⚠️  Found customer module in main.tf. Please remove manually or confirm destruction.${NC}"
    fi

    # Destroy the customer stack
    terraform destroy \
        -target="module.customer_${CUSTOMER_NAME}" \
        -auto-approve

    echo -e "${GREEN}✅ Customer ${CUSTOMER_NAME} infrastructure destroyed${NC}"
else
    echo -e "${GREEN}🚀 Deploying TAK infrastructure${NC}"
    echo "Customer: $CUSTOMER_NAME"
    echo "Tier: $TIER"
    echo "NERVA Mode: $NERVA_MODE"
    echo ""

    # Get priority
    PRIORITY=$(get_next_priority)

    # Check if customer module already exists
    if grep -q "module \"customer_${CUSTOMER_NAME}\"" main.tf; then
        echo -e "${YELLOW}⚠️  Customer ${CUSTOMER_NAME} already exists in configuration${NC}"
        echo "Updating existing deployment..."
    else
        echo -e "${GREEN}📝 Adding customer module to configuration...${NC}"

        # Append customer module to main.tf
        cat >> main.tf <<EOF

# Customer: ${CUSTOMER_NAME}
module "customer_${CUSTOMER_NAME}" {
  source = "./modules/customer-stack"

  customer_name  = "${CUSTOMER_NAME}"
  customer_tier  = "${TIER}"
  environment    = var.environment
  aws_region     = var.aws_region
  nerva_mode     = "${NERVA_MODE}"

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
  alb_rule_priority   = ${PRIORITY}
}

output "customer_${CUSTOMER_NAME}_url" {
  description = "TAK server URL for ${CUSTOMER_NAME}"
  value       = module.customer_${CUSTOMER_NAME}.customer_url
}
EOF
        echo -e "${GREEN}✅ Module added to configuration${NC}"
    fi

    # Apply terraform
    echo -e "${GREEN}🔨 Applying Terraform configuration...${NC}"
    terraform apply \
        -target="module.customer_${CUSTOMER_NAME}" \
        -auto-approve

    # Get outputs
    echo ""
    echo -e "${GREEN}======================================${NC}"
    echo -e "${GREEN}   DEPLOYMENT COMPLETE${NC}"
    echo -e "${GREEN}======================================${NC}"
    echo ""
    echo "Customer: ${CUSTOMER_NAME}"
    echo "Tier: ${TIER}"

    CUSTOMER_URL=$(terraform output -raw "customer_${CUSTOMER_NAME}_url" 2>/dev/null || echo "https://${CUSTOMER_NAME}.tak.nervsystems.com")
    echo "URL: ${CUSTOMER_URL}"
    echo ""
    echo "Next steps:"
    echo "1. Wait 5-10 minutes for ECS tasks to start"
    echo "2. Check ECS service status in AWS Console"
    echo "3. Retrieve admin certificate from container"
    echo "4. Access TAK server web UI"
    echo ""
    echo "Useful commands:"
    echo "  aws ecs describe-services --cluster tak-prod-cluster --services tak-${CUSTOMER_NAME}"
    echo "  aws logs tail /ecs/tak-prod --follow --filter-pattern ${CUSTOMER_NAME}"
    echo ""
fi
