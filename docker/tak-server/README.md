# TAK Server Docker Container

Official TAK Server packaged for container deployment.

## Building

1. **Download TAK Server** from tak.gov:
   - Visit: https://tak.gov/products/tak-server
   - Download: `takserver-docker-5.5-RELEASE58.zip` (or your target version)
   - Place in this directory

2. **Build the image:**
   ```bash
   docker build -t nerv-tak-server:5.5 \
     --build-arg TAK_VERSION=5.5-RELEASE58 .
   ```

## Configuration

The container is configured via environment variables:

### Database Connection
- `DB_HOST` - PostgreSQL hostname (default: postgres)
- `DB_PORT` - PostgreSQL port (default: 5432)
- `DB_NAME` - Database name (default: cot)
- `DB_USER` - Database user (default: takserver)
- `DB_PASSWORD` - Database password (required)

### Certificate Details
- `TAK_CERT_ORG` - Organization name (default: NERV Systems)
- `TAK_CERT_OU` - Organizational unit (default: TAK)
- `TAK_CERT_CITY` - City (default: Singapore)
- `TAK_CERT_STATE` - State/Province (default: Singapore)
- `TAK_CERT_COUNTRY` - Country code (default: SG)

## Volumes

The container expects these volumes:

- `/opt/tak/certs` - SSL certificates (generated on first run)
- `/opt/tak/logs` - TAK server logs
- `/opt/tak/db-utils` - Database utilities

## Ports

- `8089` - TAK Server API
- `8443` - Web UI (HTTPS)
- `8444` - Certificate enrollment
- `8446` - Federation
- `9000` - Streaming
- `9001` - Streaming with TLS

## First Run

On first startup, the container will:
1. Wait for PostgreSQL to be ready
2. Generate SSL certificates (CA, server, admin)
3. Configure database connection
4. Initialize database schema
5. Start TAK Server

## Accessing Admin UI

1. **Get admin certificate:**
   ```bash
   docker cp tak-server:/opt/tak/certs/admin.p12 ./admin.p12
   ```

2. **Import into browser:**
   - Chrome/Edge: Settings → Privacy and security → Manage certificates
   - Firefox: Settings → Privacy & Security → View Certificates
   - Password: `atakatak`

3. **Access Web UI:**
   ```
   https://localhost:8443
   ```

## NERVA Integration

NERVA connects to TAK Server via:

1. **TAK API** - REST endpoints on port 8089/8443
2. **PostgreSQL** - Direct database access
3. **Certificates** - Shared volume at `/opt/tak/certs`

Example NERVA sidecar configuration:
```yaml
nerva:
  environment:
    - TAK_HOST=tak-server
    - TAK_PORT=8089
    - DB_HOST=postgres
    - DB_USER=takserver
  volumes:
    - tak-certs:/certs:ro
```

## Troubleshooting

### Check logs
```bash
docker logs tak-server
docker exec tak-server cat /opt/tak/logs/takserver.log
```

### Test database connection
```bash
docker exec tak-server pg_isready -h postgres -U takserver
```

### Verify certificates
```bash
docker exec tak-server ls -la /opt/tak/certs/
```

### Access container shell
```bash
docker exec -it tak-server bash
```
