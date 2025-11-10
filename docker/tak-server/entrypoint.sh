#!/bin/bash
set -e

echo "🚀 Starting TAK Server..."

# Run setup (idempotent)
/opt/tak/setup.sh

# Start TAK Server
echo "▶️  Launching TAK Server process..."
cd /opt/tak

# Start the TAK server
if [ -f "takserver.sh" ]; then
    exec ./takserver.sh
elif [ -f "tak/takserver.sh" ]; then
    cd tak
    exec ./takserver.sh
else
    echo "❌ TAK Server startup script not found"
    exit 1
fi
