# Complete OpenClaw Jetson Deployment - Master Script

## Objective
Deploy OpenClaw on Jetson Nano with a single automated script.

## Target Device
- Host: 192.168.50.69
- User: john
- Device: NVIDIA Jetson Nano 8GB

## Quick Start

### One-Command Deployment
Run this from your Mac to deploy everything:

```bash
# Set your API key first
export ANTHROPIC_API_KEY="sk-ant-your-key-here"

# Run the master deployment script
ssh john@192.168.50.69 "ANTHROPIC_API_KEY='$ANTHROPIC_API_KEY' bash -s" << 'MASTERSCRIPT'
#!/bin/bash
set -e

echo "========================================================"
echo "OpenClaw Jetson Nano Deployment Script"
echo "========================================================"
echo ""

# Configuration
OPENCLAW_DIR="$HOME/openclaw"
GATEWAY_TOKEN=$(openssl rand -hex 32)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Step 1: Check Docker
log_info "Checking Docker installation..."
if ! command -v docker &> /dev/null; then
    log_warn "Docker not found. Installing..."
    
    sudo apt-get update
    sudo apt-get install -y \
        apt-transport-https \
        ca-certificates \
        curl \
        gnupg \
        lsb-release
    
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    
    echo "deb [arch=arm64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    sudo apt-get update
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
    
    sudo usermod -aG docker $USER
    sudo systemctl enable docker
    sudo systemctl start docker
    
    log_info "Docker installed successfully"
else
    log_info "Docker already installed: $(docker --version)"
fi

# Step 2: Create directories
log_info "Creating OpenClaw directories..."
mkdir -p "$OPENCLAW_DIR"
mkdir -p "$HOME/.openclaw"
mkdir -p "$HOME/.openclaw/workspace"

# Step 3: Create Dockerfile
log_info "Creating Dockerfile..."
cat > "$OPENCLAW_DIR/Dockerfile" << 'DOCKERFILE'
FROM arm64v8/node:22-bookworm

ENV NODE_ENV=production
ENV PNPM_HOME="/pnpm"
ENV PATH="$PNPM_HOME:$PATH"

RUN apt-get update && apt-get install -y \
    git curl build-essential python3 \
    && rm -rf /var/lib/apt/lists/*

RUN corepack enable && corepack prepare pnpm@latest --activate

RUN curl -fsSL https://bun.sh/install | bash
ENV PATH="/root/.bun/bin:${PATH}"

WORKDIR /app

RUN git clone --depth 1 https://github.com/openclaw/openclaw.git .

RUN pnpm install --frozen-lockfile
RUN pnpm build
RUN pnpm ui:install || true
RUN pnpm ui:build || true

RUN useradd -m -s /bin/bash openclaw && chown -R openclaw:openclaw /app
USER openclaw

EXPOSE 18789

HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD node dist/index.js health --token "${OPENCLAW_GATEWAY_TOKEN}" || exit 1

CMD ["node", "dist/index.js", "gateway", "--bind", "lan", "--port", "18789"]
DOCKERFILE

# Step 4: Create docker-compose.yml
log_info "Creating docker-compose.yml..."
cat > "$OPENCLAW_DIR/docker-compose.yml" << 'COMPOSE'
version: '3.8'

services:
  openclaw-gateway:
    build:
      context: .
      dockerfile: Dockerfile
    image: openclaw-jetson:local
    container_name: openclaw
    restart: unless-stopped
    ports:
      - "18789:18789"
    volumes:
      - openclaw-config:/home/openclaw/.openclaw
      - openclaw-workspace:/home/openclaw/.openclaw/workspace
    environment:
      - NODE_ENV=production
      - OPENCLAW_GATEWAY_TOKEN=${OPENCLAW_GATEWAY_TOKEN:-}
      - ANTHROPIC_API_KEY=${ANTHROPIC_API_KEY:-}
      - OPENAI_API_KEY=${OPENAI_API_KEY:-}
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"

  openclaw-cli:
    build:
      context: .
      dockerfile: Dockerfile
    image: openclaw-jetson:local
    volumes:
      - openclaw-config:/home/openclaw/.openclaw
      - openclaw-workspace:/home/openclaw/.openclaw/workspace
    environment:
      - NODE_ENV=production
      - OPENCLAW_GATEWAY_TOKEN=${OPENCLAW_GATEWAY_TOKEN:-}
      - ANTHROPIC_API_KEY=${ANTHROPIC_API_KEY:-}
    profiles:
      - cli
    entrypoint: ["node", "dist/index.js"]
    stdin_open: true
    tty: true

volumes:
  openclaw-config:
  openclaw-workspace:
COMPOSE

# Step 5: Create .env file
log_info "Creating .env file..."
cat > "$OPENCLAW_DIR/.env" << ENVFILE
OPENCLAW_GATEWAY_TOKEN=$GATEWAY_TOKEN
ANTHROPIC_API_KEY=${ANTHROPIC_API_KEY:-}
OPENAI_API_KEY=${OPENAI_API_KEY:-}
ENVFILE

# Step 6: Create management scripts
log_info "Creating management scripts..."

cat > "$OPENCLAW_DIR/start.sh" << 'SCRIPT'
#!/bin/bash
cd ~/openclaw && docker compose up -d openclaw-gateway
echo "OpenClaw started. Logs: docker logs -f openclaw"
SCRIPT

cat > "$OPENCLAW_DIR/stop.sh" << 'SCRIPT'
#!/bin/bash
cd ~/openclaw && docker compose down
SCRIPT

cat > "$OPENCLAW_DIR/logs.sh" << 'SCRIPT'
#!/bin/bash
docker logs -f openclaw
SCRIPT

cat > "$OPENCLAW_DIR/status.sh" << 'SCRIPT'
#!/bin/bash
echo "=== Container Status ===" && docker ps -a | grep openclaw
echo "" && echo "=== Resource Usage ===" && docker stats --no-stream openclaw 2>/dev/null || echo "Not running"
SCRIPT

cat > "$OPENCLAW_DIR/rebuild.sh" << 'SCRIPT'
#!/bin/bash
cd ~/openclaw && docker compose down && docker compose build --no-cache && docker compose up -d openclaw-gateway
SCRIPT

chmod +x "$OPENCLAW_DIR"/*.sh

# Step 7: Build Docker image
log_info "Building Docker image (this may take 15-30 minutes)..."
cd "$OPENCLAW_DIR"
sudo docker compose build

# Step 8: Start OpenClaw
log_info "Starting OpenClaw gateway..."
sudo docker compose up -d openclaw-gateway

# Step 9: Wait for startup
log_info "Waiting for gateway to initialize..."
sleep 15

# Step 10: Get IP address
JETSON_IP=$(hostname -I | awk '{print $1}')

# Final output
echo ""
echo "========================================================"
echo -e "${GREEN}OpenClaw Deployment Complete!${NC}"
echo "========================================================"
echo ""
echo "Gateway URL: http://$JETSON_IP:18789"
echo "Gateway Token: $GATEWAY_TOKEN"
echo ""
echo "Control UI URL:"
echo "  http://$JETSON_IP:18789/?token=$GATEWAY_TOKEN"
echo ""
echo "Management Commands (run on Jetson):"
echo "  ~/openclaw/start.sh   - Start OpenClaw"
echo "  ~/openclaw/stop.sh    - Stop OpenClaw"
echo "  ~/openclaw/logs.sh    - View logs"
echo "  ~/openclaw/status.sh  - Check status"
echo "  ~/openclaw/rebuild.sh - Rebuild and restart"
echo ""
echo "Next Steps:"
echo "  1. Open the Control UI in your browser"
echo "  2. Run onboarding: ssh -t john@$JETSON_IP 'cd ~/openclaw && sudo docker compose run --rm openclaw-cli onboard'"
echo "  3. Add channels (Telegram, Discord, etc.)"
echo ""
echo "========================================================"
MASTERSCRIPT
```

## Post-Deployment Commands

### Access Control UI
Open in browser:
```
http://192.168.50.69:18789/?token=YOUR_GATEWAY_TOKEN
```

### Run Onboarding
```bash
ssh -t john@192.168.50.69 "cd ~/openclaw && sudo docker compose run --rm openclaw-cli onboard"
```

### Add Telegram Bot
```bash
ssh john@192.168.50.69 "cd ~/openclaw && sudo docker compose run --rm openclaw-cli channels add --channel telegram --token 'YOUR_BOT_TOKEN'"
```

### View Logs
```bash
ssh john@192.168.50.69 "docker logs -f openclaw"
```

### Check Status
```bash
ssh john@192.168.50.69 "~/openclaw/status.sh"
```

## Troubleshooting

### Container won't start
```bash
ssh john@192.168.50.69 "docker logs openclaw 2>&1 | tail -50"
```

### Out of memory during build
```bash
# Create swap file on Jetson
ssh john@192.168.50.69 << 'EOF'
sudo fallocate -l 4G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
EOF
```

### Rebuild from scratch
```bash
ssh john@192.168.50.69 << 'EOF'
cd ~/openclaw
docker compose down
docker system prune -af
docker compose build --no-cache
docker compose up -d openclaw-gateway
EOF
```

### Check Jetson resources
```bash
ssh john@192.168.50.69 "free -h && df -h && docker stats --no-stream"
```

## Environment Variables Reference

| Variable | Description | Required |
|----------|-------------|----------|
| OPENCLAW_GATEWAY_TOKEN | Authentication token for gateway | Yes |
| ANTHROPIC_API_KEY | Anthropic Claude API key | Yes* |
| OPENAI_API_KEY | OpenAI API key | No |
| OPENROUTER_API_KEY | OpenRouter API key | No |

*At least one AI provider API key is required.

## Ports Reference

| Port | Service | Description |
|------|---------|-------------|
| 18789 | Gateway | Main OpenClaw gateway and Control UI |

## Expected Outcomes
- Docker installed and configured on Jetson
- OpenClaw container built and running
- Gateway accessible from local network
- Management scripts available for easy operation
- Ready for channel configuration and onboarding
