#!/bin/bash
set -e

echo "🔍 Retrieving Airflow admin password from webserver logs..."

# Wait for webserver to be ready
echo "⏳ Waiting for webserver to start..."
for i in {1..30}; do
    if docker ps | grep -q "hirewire_airflow_webserver.*Up"; then
        echo "✅ Webserver ready!"
        break
    fi
    sleep 1
done

# Extract password from logs (BSD grep compatible)
PASSWORD=$(docker logs hirewire_airflow_webserver 2>&1 | grep "Password for user 'admin':" | tail -1 | awk -F': ' '{print $NF}')

if [ -z "$PASSWORD" ]; then
    echo "❌ Could not find admin password in logs"
    echo "📋 Full logs:"
    docker logs hirewire_airflow_webserver 2>&1 | grep -i "password\|admin" | tail -5
    exit 1
fi

echo "✅ Admin password retrieved successfully"
echo ""
echo "═══════════════════════════════════════"
echo "👤 Username: admin"
echo "🔑 Password: $PASSWORD"
echo "🌐 URL: http://localhost:8080"
echo "═══════════════════════════════════════"
echo ""
echo "💡 This password is auto-generated on each container restart"
echo "💡 Run this script again after rebuilding containers"

