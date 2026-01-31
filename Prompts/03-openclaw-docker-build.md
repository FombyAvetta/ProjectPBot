# Build and Deploy OpenClaw on Jetson Nano

## Objective
Build and run OpenClaw in a Docker container on the Jetson Nano.

## Target Device
- Host: 192.168.50.69
- User: john
- Device: NVIDIA Jetson Nano 8GB

## Prerequisites
- Docker installed (see 02-jetson-docker-install.md)
- SSH access configured (see 01-jetson-ssh-setup.md)

## Tasks

### 1. Create OpenClaw Directory Structure
```bash
ssh john@192.168.50.69 << 'EOF'
mkdir -p ~/openclaw
mkdir -p ~/.openclaw
mkdir -p ~/.openclaw/workspace
cd ~/openclaw
echo "OpenClaw directory created at ~/openclaw"
EOF
```

### 2. Create ARM64-Optimized Dockerfile
```bash
ssh john@192.168.50.69 << 'EOF'
cat > ~/openclaw/Dockerfile << 'DOCKERFILE'
# OpenClaw Dockerfile for Jetson Nano (ARM64)
FROM arm64v8/node:22-bookworm

# Set environment variables
ENV NODE_ENV=production
ENV PNPM_HOME="/pnpm"
ENV PATH="$PNPM_HOME:$PATH"

# Install system dependencies
RUN apt-get update && apt-get install -y \
    git \
    curl \
    build-essential \
    python3 \
    chromium \
    chromium-driver \
    && rm -rf /var/lib/apt/lists/*

# Install pnpm
RUN corepack enable && corepack prepare pnpm@latest --activate

# Install Bun (required for build scripts)
RUN curl -fsSL https://bun.sh/install | bash
ENV PATH="/root/.bun/bin:${PATH}"

# Create app directory
WORKDIR /app

# Clone OpenClaw repository
RUN git clone --depth 1 https://github.com/openclaw/openclaw.git .

# Install dependencies
RUN pnpm install --frozen-lockfile

# Build the application
RUN pnpm build

# Build UI
RUN pnpm ui:install || true
RUN pnpm ui:build || true

# Create non-root user
RUN useradd -m -s /bin/bash openclaw && \
    chown -R openclaw:openclaw /app

# Switch to non-root user
USER openclaw

# Expose gateway port
EXPOSE 18789

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD node dist/index.js health --token "${OPENCLAW_GATEWAY_TOKEN}" || exit 1

# Default command - start gateway bound to all interfaces
CMD ["node", "dist/index.js", "gateway", "--bind", "lan", "--port", "18789"]
DOCKERFILE

echo "Dockerfile created"
EOF
```

### 3. Create Docker Compose File
```bash
ssh john@192.168.50.69 << 'EOF'
cat > ~/openclaw/docker-compose.yml << 'COMPOSE'
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
      - ./config:/app/config:ro
    environment:
      - NODE_ENV=production
      - OPENCLAW_GATEWAY_TOKEN=${OPENCLAW_GATEWAY_TOKEN:-}
      - ANTHROPIC_API_KEY=${ANTHROPIC_API_KEY:-}
      - OPENAI_API_KEY=${OPENAI_API_KEY:-}
      - OPENROUTER_API_KEY=${OPENROUTER_API_KEY:-}
    networks:
      - openclaw-net
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
    container_name: openclaw-cli
    volumes:
      - openclaw-config:/home/openclaw/.openclaw
      - openclaw-workspace:/home/openclaw/.openclaw/workspace
    environment:
      - NODE_ENV=production
      - OPENCLAW_GATEWAY_TOKEN=${OPENCLAW_GATEWAY_TOKEN:-}
      - ANTHROPIC_API_KEY=${ANTHROPIC_API_KEY:-}
    networks:
      - openclaw-net
    profiles:
      - cli
    entrypoint: ["node", "dist/index.js"]
    stdin_open: true
    tty: true

volumes:
  openclaw-config:
  openclaw-workspace:

networks:
  openclaw-net:
    driver: bridge
COMPOSE

echo "docker-compose.yml created"
EOF
```

### 4. Create Environment File Template
```bash
ssh john@192.168.50.69 << 'EOF'
cat > ~/openclaw/.env.example << 'ENVFILE'
# OpenClaw Environment Configuration
# Copy this to .env and fill in your values

# Gateway Authentication Token (generate a secure random string)
OPENCLAW_GATEWAY_TOKEN=your-secure-token-here

# AI Provider API Keys (add the ones you want to use)
ANTHROPIC_API_KEY=sk-ant-your-key-here
# OPENAI_API_KEY=sk-your-key-here
# OPENROUTER_API_KEY=your-key-here
# GEMINI_API_KEY=your-key-here

# Optional: Model Configuration
# DEFAULT_MODEL=claude-sonnet-4-20250514
ENVFILE

echo ".env.example created - copy to .env and add your API keys"
EOF
```

### 5. Create Build and Run Script
```bash
ssh john@192.168.50.69 << 'EOF'
cat > ~/openclaw/setup.sh << 'SCRIPT'
#!/bin/bash
set -e

cd ~/openclaw

echo "============================================"
echo "OpenClaw Setup for Jetson Nano"
echo "============================================"

# Check for .env file
if [ ! -f .env ]; then
    echo ""
    echo "WARNING: No .env file found!"
    echo "Creating from template..."
    cp .env.example .env
    
    # Generate a random gateway token
    RANDOM_TOKEN=$(openssl rand -hex 32)
    sed -i "s/your-secure-token-here/$RANDOM_TOKEN/" .env
    
    echo ""
    echo "Generated gateway token: $RANDOM_TOKEN"
    echo ""
    echo "Please edit ~/openclaw/.env and add your API keys:"
    echo "  nano ~/openclaw/.env"
    echo ""
    echo "Then run this script again."
    exit 1
fi

# Load environment variables
export $(grep -v '^#' .env | xargs)

echo ""
echo "Step 1: Building Docker image (this may take 15-30 minutes on Jetson)..."
echo ""
docker compose build --no-cache

echo ""
echo "Step 2: Starting OpenClaw gateway..."
echo ""
docker compose up -d openclaw-gateway

echo ""
echo "Step 3: Waiting for gateway to start..."
sleep 10

echo ""
echo "============================================"
echo "OpenClaw Setup Complete!"
echo "============================================"
echo ""
echo "Gateway URL: http://$(hostname -I | awk '{print $1}'):18789"
echo "Gateway Token: $OPENCLAW_GATEWAY_TOKEN"
echo ""
echo "Access the Control UI at:"
echo "  http://$(hostname -I | awk '{print $1}'):18789/?token=$OPENCLAW_GATEWAY_TOKEN"
echo ""
echo "Useful commands:"
echo "  View logs:        docker logs -f openclaw"
echo "  Stop:             docker compose down"
echo "  Restart:          docker compose restart"
echo "  Run CLI:          docker compose run --rm openclaw-cli <command>"
echo "  Onboard:          docker compose run --rm openclaw-cli onboard"
echo "  Add Telegram:     docker compose run --rm openclaw-cli channels add --channel telegram --token <BOT_TOKEN>"
echo ""
SCRIPT

chmod +x ~/openclaw/setup.sh
echo "setup.sh created and made executable"
EOF
```

### 6. Create Management Scripts
```bash
ssh john@192.168.50.69 << 'EOF'
# Start script
cat > ~/openclaw/start.sh << 'SCRIPT'
#!/bin/bash
cd ~/openclaw
docker compose up -d openclaw-gateway
echo "OpenClaw started. View logs with: docker logs -f openclaw"
SCRIPT
chmod +x ~/openclaw/start.sh

# Stop script
cat > ~/openclaw/stop.sh << 'SCRIPT'
#!/bin/bash
cd ~/openclaw
docker compose down
echo "OpenClaw stopped"
SCRIPT
chmod +x ~/openclaw/stop.sh

# Logs script
cat > ~/openclaw/logs.sh << 'SCRIPT'
#!/bin/bash
docker logs -f openclaw
SCRIPT
chmod +x ~/openclaw/logs.sh

# Status script
cat > ~/openclaw/status.sh << 'SCRIPT'
#!/bin/bash
echo "=== Container Status ==="
docker ps -a | grep openclaw
echo ""
echo "=== Resource Usage ==="
docker stats --no-stream openclaw 2>/dev/null || echo "Container not running"
SCRIPT
chmod +x ~/openclaw/status.sh

# Rebuild script
cat > ~/openclaw/rebuild.sh << 'SCRIPT'
#!/bin/bash
cd ~/openclaw
echo "Stopping OpenClaw..."
docker compose down
echo "Rebuilding image..."
docker compose build --no-cache
echo "Starting OpenClaw..."
docker compose up -d openclaw-gateway
echo "Rebuild complete. View logs with: docker logs -f openclaw"
SCRIPT
chmod +x ~/openclaw/rebuild.sh

echo "Management scripts created: start.sh, stop.sh, logs.sh, status.sh, rebuild.sh"
EOF
```

## Running the Installation

### Step 1: Run the setup
```bash
ssh john@192.168.50.69 "cd ~/openclaw && ./setup.sh"
```

### Step 2: Add your API key (if not done)
```bash
ssh john@192.168.50.69 "nano ~/openclaw/.env"
# Add your ANTHROPIC_API_KEY or other provider keys
```

### Step 3: Rebuild and start
```bash
ssh john@192.168.50.69 "cd ~/openclaw && ./setup.sh"
```

### Step 4: Run onboarding (interactive)
```bash
ssh -t john@192.168.50.69 "cd ~/openclaw && docker compose run --rm openclaw-cli onboard"
```

## Verification
```bash
# Check container is running
ssh john@192.168.50.69 "docker ps | grep openclaw"

# Check logs
ssh john@192.168.50.69 "docker logs openclaw 2>&1 | tail -20"

# Test health endpoint
ssh john@192.168.50.69 "curl -s http://localhost:18789/health"
```

## Access OpenClaw
After setup, access the Control UI from your browser:
```
http://192.168.50.69:18789/?token=YOUR_GATEWAY_TOKEN
```

## Expected Outcomes
- OpenClaw Docker image built for ARM64
- Gateway running and accessible on port 18789
- Configuration persisted in Docker volumes
- Management scripts for easy operation
