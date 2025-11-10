# NERVA AI Sidecar Container

This directory will contain your NERVA Go microservices container.

## Integration with TAK Server

NERVA runs as a sidecar container alongside TAK Server and connects via:

### 1. TAK Server API
- **Endpoint:** `https://tak-server:8443/Marti/api/`
- **Port:** 8089 (unencrypted) or 8443 (HTTPS)
- **Authentication:** Certificate-based (mutual TLS)

### 2. PostgreSQL Database
- **Direct access** to TAK's PostgreSQL database
- **Schema:** `cot` (Cursor on Target)
- **Tables:** Mission data, CoT events, user info

### 3. Shared Certificates
- **Volume mount:** `/certs` (read-only)
- **Files needed:**
  - `ca.crt` - Certificate Authority
  - `admin.crt` / `admin.key` - Client certificate
  - `takserver.crt` - Server certificate

## Environment Variables

Your NERVA container will receive these environment variables:

```bash
# TAK Server connection
TAK_HOST=tak-server
TAK_PORT=8089
TAK_API_URL=https://tak-server:8443

# Database connection
DB_HOST=postgres
DB_PORT=5432
DB_NAME=cot
DB_USER=takserver
DB_PASSWORD=<from secrets>

# NERVA operational mode
NERVA_MODE=full  # lite, full, custom
```

## Dockerfile Example

```dockerfile
FROM golang:1.21-alpine AS builder
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN go build -o nerva ./cmd/nerva

FROM alpine:latest
RUN apk add --no-cache ca-certificates postgresql-client
COPY --from=builder /app/nerva /usr/local/bin/nerva
ENTRYPOINT ["/usr/local/bin/nerva"]
```

## Building Your NERVA Image

```bash
# Build NERVA container
cd docker/nerva
docker build -t nervsystems/nerva:latest .

# Test locally
docker run --rm -e TAK_HOST=tak-server nervsystems/nerva:latest
```

## TAK Connector Requirements

Your TAK connector microservice should:

1. **Wait for TAK Server** to be healthy before connecting
2. **Use certificates** from `/certs` volume for SSL/TLS
3. **Connect to PostgreSQL** using provided credentials
4. **Handle reconnection** if TAK Server restarts
5. **Log to stdout/stderr** (captured by Docker/ECS)

## Testing NERVA Connectivity

```bash
# Check if NERVA can reach TAK Server
docker exec nerva curl -k https://tak-server:8443/Marti/api/version

# Check database connectivity
docker exec nerva psql -h postgres -U takserver -d cot -c "SELECT 1"

# Verify certificates are accessible
docker exec nerva ls -la /certs/
```

## Deployment

### Local Development
```yaml
# docker-compose.yml
nerva:
  image: nervsystems/nerva:latest
  environment:
    - TAK_HOST=tak-server
  volumes:
    - tak-certs:/certs:ro
```

### AWS ECS
```json
{
  "name": "nerva",
  "image": "123456789012.dkr.ecr.us-east-1.amazonaws.com/nerva:latest",
  "environment": [
    {"name": "TAK_HOST", "value": "localhost"},
    {"name": "DB_HOST", "value": "customer-db.xxx.rds.amazonaws.com"}
  ]
}
```

### On-Premise
Same docker-compose.yml, just point to local TAK Server.

## Next Steps

1. **Replace Dockerfile.placeholder** with your actual NERVA build
2. **Test locally** with docker-compose
3. **Push to ECR** for AWS deployment
4. **Update docker-compose.yml** with your NERVA image name
