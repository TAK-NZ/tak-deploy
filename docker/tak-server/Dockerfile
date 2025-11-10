FROM eclipse-temurin:17-jre-jammy

# Install dependencies
RUN apt-get update && apt-get install -y \
    curl \
    unzip \
    postgresql-client \
    netcat \
    openssl \
    && rm -rf /var/lib/apt/lists/*

# Create TAK user and directories
RUN useradd -r -u 1000 -m -s /bin/bash tak && \
    mkdir -p /opt/tak /opt/tak/certs /opt/tak/logs /opt/tak/db-utils && \
    chown -R tak:tak /opt/tak

WORKDIR /opt/tak

# Copy TAK server zip file (must be provided during build)
ARG TAK_VERSION=5.5-RELEASE58
COPY takserver-docker-${TAK_VERSION}.zip /tmp/

# Extract and set up TAK server
RUN unzip -q /tmp/takserver-docker-${TAK_VERSION}.zip -d /opt/tak && \
    rm /tmp/takserver-docker-${TAK_VERSION}.zip && \
    chown -R tak:tak /opt/tak

# Copy setup and entrypoint scripts
COPY --chown=tak:tak setup.sh /opt/tak/
COPY --chown=tak:tak entrypoint.sh /opt/tak/
RUN chmod +x /opt/tak/setup.sh /opt/tak/entrypoint.sh

# Expose ports
# 8089: TAK Server API
# 8443: Web UI
# 8444: Certificate enrollment
# 8446: Federation
# 9000: Streaming
# 9001: Streaming TLS
EXPOSE 8089 8443 8444 8446 9000 9001

USER tak

ENTRYPOINT ["/opt/tak/entrypoint.sh"]
