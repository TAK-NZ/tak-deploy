#!/bin/bash
set -e

echo "🚀 TAK Server Setup Starting..."

# Configuration from environment variables
DB_HOST="${DB_HOST:-postgres}"
DB_PORT="${DB_PORT:-5432}"
DB_NAME="${DB_NAME:-cot}"
DB_USER="${DB_USER:-takserver}"
DB_PASSWORD="${DB_PASSWORD}"

TAK_CERT_ORG="${TAK_CERT_ORG:-NERV Systems}"
TAK_CERT_OU="${TAK_CERT_OU:-TAK}"
TAK_CERT_CITY="${TAK_CERT_CITY:-Singapore}"
TAK_CERT_STATE="${TAK_CERT_STATE:-Singapore}"
TAK_CERT_COUNTRY="${TAK_CERT_COUNTRY:-SG}"

# Wait for PostgreSQL to be ready
echo "⏳ Waiting for PostgreSQL at ${DB_HOST}:${DB_PORT}..."
max_attempts=30
attempt=0
until pg_isready -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" || [ $attempt -eq $max_attempts ]; do
    attempt=$((attempt + 1))
    echo "  Attempt $attempt/$max_attempts..."
    sleep 2
done

if [ $attempt -eq $max_attempts ]; then
    echo "❌ Failed to connect to PostgreSQL"
    exit 1
fi

echo "✅ PostgreSQL is ready"

# Configure database connection
echo "🔧 Configuring TAK Server database connection..."
cd /opt/tak

# Update CoreConfig.xml with database settings
if [ -f "CoreConfig.xml" ]; then
    # Backup original
    cp CoreConfig.xml CoreConfig.xml.bak

    # Update database connection details
    sed -i "s/<connection .*/connection url=\"jdbc:postgresql:\/\/${DB_HOST}:${DB_PORT}\/${DB_NAME}?stringtype=unspecified\" username=\"${DB_USER}\" password=\"${DB_PASSWORD}\"\/>/g" CoreConfig.xml
fi

# Generate certificates if they don't exist
if [ ! -f "/opt/tak/certs/takserver.jks" ]; then
    echo "🔐 Generating TAK Server certificates..."

    cd /opt/tak/certs

    # Certificate details
    CERT_STATE="$TAK_CERT_STATE"
    CERT_CITY="$TAK_CERT_CITY"
    CERT_ORG="$TAK_CERT_ORG"
    CERT_OU="$TAK_CERT_OU"

    # Generate CA
    echo "  Generating Certificate Authority..."
    openssl req -new -x509 -days 3650 -extensions v3_ca \
        -keyout ca.key -out ca.crt \
        -passout pass:atakatak \
        -subj "/C=${TAK_CERT_COUNTRY}/ST=${CERT_STATE}/L=${CERT_CITY}/O=${CERT_ORG}/OU=${CERT_OU}/CN=NERV TAK CA"

    # Generate server certificate
    echo "  Generating TAK Server certificate..."
    openssl req -new -newkey rsa:2048 -nodes \
        -keyout takserver.key -out takserver.csr \
        -subj "/C=${TAK_CERT_COUNTRY}/ST=${CERT_STATE}/L=${CERT_CITY}/O=${CERT_ORG}/OU=${CERT_OU}/CN=takserver"

    openssl x509 -req -days 3650 \
        -in takserver.csr -CA ca.crt -CAkey ca.key \
        -CAcreateserial -out takserver.crt \
        -passin pass:atakatak

    # Create Java keystore
    echo "  Creating Java keystores..."
    openssl pkcs12 -export -in takserver.crt -inkey takserver.key \
        -out takserver.p12 -name takserver \
        -passout pass:atakatak

    keytool -importkeystore -deststorepass atakatak \
        -destkeypass atakatak -destkeystore takserver.jks \
        -srckeystore takserver.p12 -srcstoretype PKCS12 \
        -srcstorepass atakatak -alias takserver -noprompt

    # Import CA into truststore
    keytool -import -trustcacerts -file ca.crt \
        -keystore truststore-root.jks -storepass atakatak \
        -noprompt -alias ca

    # Generate admin certificate
    echo "  Generating admin client certificate..."
    openssl req -new -newkey rsa:2048 -nodes \
        -keyout admin.key -out admin.csr \
        -subj "/C=${TAK_CERT_COUNTRY}/ST=${CERT_STATE}/L=${CERT_CITY}/O=${CERT_ORG}/OU=${CERT_OU}/CN=admin"

    openssl x509 -req -days 3650 \
        -in admin.csr -CA ca.crt -CAkey ca.key \
        -CAcreateserial -out admin.crt \
        -passin pass:atakatak

    openssl pkcs12 -export -in admin.crt -inkey admin.key \
        -out admin.p12 -name admin \
        -passout pass:atakatak

    echo "✅ Certificates generated"
else
    echo "✅ Certificates already exist"
fi

# Initialize database
echo "📊 Checking database initialization..."
if ! PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" -c "SELECT 1 FROM information_schema.tables WHERE table_name='cot_router'" &>/dev/null; then
    echo "  Initializing TAK database schema..."
    if [ -f "/opt/tak/db-utils/takserver-setup-db.sh" ]; then
        cd /opt/tak/db-utils
        ./takserver-setup-db.sh
    fi
    echo "✅ Database initialized"
else
    echo "✅ Database already initialized"
fi

echo "🎉 TAK Server setup complete!"
