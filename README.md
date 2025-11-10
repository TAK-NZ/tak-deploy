# NERV TAK Deployment

Portable TAK Server deployment for NERV Systems - works on AWS, on-premise, or field-deployable hardware.

## Architecture

This deployment is built for maximum portability:

- **Core containers** (TAK Server + NERVA + PostgreSQL) are identical across all deployment targets
- **Deployment layer** adapts to your environment (AWS ECS, on-prem Docker, or field box)
- **Single source of truth** for TAK configuration

## Deployment Options

### 1. AWS Cloud (SaaS)
Fully managed customer deployments on AWS ECS Fargate with RDS PostgreSQL.

```bash
cd aws
terraform init
terraform apply
./scripts/deploy-customer.sh customer-name starter
```

**Cost per customer (us-east-1):**
- Starter (50 users): ~$71/month
- Professional (250 users): ~$145/month

### 2. On-Premise (Customer Data Center)
Self-hosted deployment for customers with data sovereignty requirements.

```bash
cd on-prem
./install.sh --domain customer.local
```

### 3. Field Deployment (Edge Device)
Ruggedized deployment for tactical operations without cloud connectivity.

```bash
cd on-prem
./install.sh --offline --interface eth0
```

### 4. Development (Local Laptop)
Quick development environment for testing.

```bash
docker-compose up
```

## Repository Structure

```
nerv-tak-deploy/
├── docker/                     # Container definitions
│   ├── tak-server/            # TAK Server container
│   └── nerva/                 # NERVA AI sidecar (placeholder)
├── docker-compose.yml         # Base deployment (works anywhere)
├── docker-compose.dev.yml     # Development overrides
├── aws/                       # AWS-specific deployment
│   ├── terraform/            # Infrastructure as code
│   └── scripts/              # Automation scripts
├── on-prem/                   # On-premise deployment
│   ├── docker-compose.prod.yml
│   └── install.sh
└── docs/                      # Documentation
```

## Quick Start (Development)

1. **Prerequisites:**
   - Docker and Docker Compose installed
   - TAK Server release zip from tak.gov

2. **Place TAK server zip:**
   ```bash
   # Download takserver-docker-5.x-RELEASEx.zip from tak.gov
   cp takserver-docker-*.zip docker/tak-server/
   ```

3. **Start services:**
   ```bash
   docker-compose up -d
   ```

4. **Access TAK Server:**
   - Web UI: https://localhost:8443
   - Admin cert: `./certs/admin.p12`

## AWS Deployment

See [AWS_DEPLOYMENT.md](docs/AWS_DEPLOYMENT.md) for detailed instructions.

**Prerequisites:**
- AWS account with credentials configured
- Terraform installed
- Domain for customer subdomains (*.tak.nervsystems.com)

**Features:**
- Automated customer provisioning
- Shared ALB for cost optimization
- RDS PostgreSQL per customer
- CloudWatch monitoring
- Automated backups
- Multi-region support (future)

## On-Premise Deployment

See [ON_PREM_DEPLOYMENT.md](docs/ON_PREM_DEPLOYMENT.md) for detailed instructions.

**Use cases:**
- Customer data center deployments
- Air-gapped environments
- Compliance requirements (data sovereignty)
- Field-deployable tactical systems

## NERVA Integration

NERVA runs as a sidecar container alongside TAK Server:

```yaml
services:
  tak-server:
    # TAK Server container

  nerva:
    image: nervsystems/nerva:latest
    environment:
      - TAK_HOST=tak-server
      - TAK_PORT=8089
    volumes:
      - tak-certs:/certs:ro
    depends_on:
      - tak-server
```

NERVA connects to TAK Server via:
- TAK API (REST)
- PostgreSQL database (direct access)
- SSL certificates (shared volume)

## Support

- **Documentation:** [docs/](docs/)
- **Issues:** GitHub Issues
- **Contact:** contact@nervsystems.com

## License

MIT License - see [LICENSE](LICENSE) for details

---

Built with ❤️ by NERV Systems for the Asia Pacific tactical community.
