#!/bin/bash
# Installer for MCP Inspector (from registry)
set -e

# Variables
BASE_DIR="${BASE_DIR:-$HOME/labs/mcp/mcp_inspector}"
IMAGE_NAME="ghcr.io/modelcontextprotocol/inspector:latest"
CONTAINER_NAME="mcp_inspector"

# Ports (host and container will be the same)
CLIENT_PORT=18567
SERVER_PORT=18568

echo "🔍 Checking if directory exists: $BASE_DIR"
mkdir -p "$BASE_DIR"
cd "$BASE_DIR"

# Pull latest image
echo "🐳 Pulling Docker image: $IMAGE_NAME"
docker pull "$IMAGE_NAME"

# Create start_service.sh
START_SCRIPT="$BASE_DIR/start_service.sh"
echo "⚙️ Creating start_service.sh"
cat > "$START_SCRIPT" <<EOL
#!/bin/bash
set -e

# Variables
CONTAINER_NAME="$CONTAINER_NAME"
IMAGE_NAME="$IMAGE_NAME"

# Host/Container ports
CLIENT_PORT=$CLIENT_PORT
SERVER_PORT=$SERVER_PORT

echo "🚀 Starting container: \$CONTAINER_NAME (client:\$CLIENT_PORT, server:\$SERVER_PORT)"

# Remove old container if exists
if docker ps -a --format '{{.Names}}' | grep -Eq "^\$CONTAINER_NAME\$"; then
  echo "⚠️ Container \$CONTAINER_NAME already exists. Removing..."
  docker stop "\$CONTAINER_NAME" || true
  docker rm "\$CONTAINER_NAME" || true
fi

# Detect public IP dynamically
PUBLIC_IP=\$(curl -s ifconfig.me || curl -s api.ipify.org)

docker run -d \\
  --name "\$CONTAINER_NAME" \\
  -p \$CLIENT_PORT:\$CLIENT_PORT \\
  -p \$SERVER_PORT:\$SERVER_PORT \\
  -e HOST=0.0.0.0 \\
  -e ALLOWED_ORIGINS="http://\$PUBLIC_IP:\$CLIENT_PORT,http://\$PUBLIC_IP:\$SERVER_PORT" \\
  -e CLIENT_PORT=\$CLIENT_PORT \\
  -e SERVER_PORT=\$SERVER_PORT \\
  "\$IMAGE_NAME"

# Wait for log output
sleep 3

# Extract the raw URL with token from logs (including MCP_PROXY_PORT)
RAW_URL=\$(docker logs "\$CONTAINER_NAME" 2>&1 \\
  | grep -Eo "http://0.0.0.0:\$CLIENT_PORT/\\?MCP_PROXY_PORT=\$SERVER_PORT&MCP_PROXY_AUTH_TOKEN=[a-f0-9]+" \\
  | tail -n1)

# Replace 0.0.0.0 with actual public IP
ACCESS_URL=\$(echo "\$RAW_URL" | sed "s|0.0.0.0|\$PUBLIC_IP|")

if [ -n "\$ACCESS_URL" ]; then
  echo "✅ MCP Inspector is available at:"
  echo "   \$ACCESS_URL"
else
  echo "❌ Could not extract access URL from logs."
  echo "📜 Full logs below:"
  docker logs "\$CONTAINER_NAME"
fi
EOL
chmod +x "$START_SCRIPT"

# Create stop_service.sh
STOP_SCRIPT="$BASE_DIR/stop_service.sh"
echo "⚙️ Creating stop_service.sh"
cat > "$STOP_SCRIPT" <<EOL
#!/bin/bash
set -e
CONTAINER_NAME="$CONTAINER_NAME"

echo "🛑 Stopping container: \$CONTAINER_NAME"

if docker ps -a --format '{{.Names}}' | grep -Eq "^\$CONTAINER_NAME\$"; then
  docker stop "\$CONTAINER_NAME" || true
  docker rm "\$CONTAINER_NAME" || true
  echo "✅ Container \$CONTAINER_NAME stopped and removed."
else
  echo "⚠️ No container named \$CONTAINER_NAME found."
fi
EOL
chmod +x "$STOP_SCRIPT"

echo ""
echo "============================================================"
echo "   MCP Inspector – Installation Complete!"
echo "============================================================"
echo ""
echo "  Directory : ${BASE_DIR}"
echo ""
echo "  Helper scripts:"
echo "    Start → ${START_SCRIPT}"
echo "    Stop  → ${STOP_SCRIPT}"
echo ""
echo "  ─── Next steps ────────────────────────────────────────"
echo "  1. Start MCP Inspector:"
echo "       ${START_SCRIPT}"
echo ""
echo "  2. The start script will print the access URL with auth token."
echo ""
echo "  3. Stop:"
echo "       ${STOP_SCRIPT}"
echo ""
