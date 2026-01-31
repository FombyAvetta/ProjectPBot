#!/bin/bash
#
# 03-openclaw-build.sh
# Build and configure OpenClaw on Jetson Nano
# This script runs ON the Jetson Nano
#

set -e

# Configuration
OPENCLAW_DIR="$HOME/openclaw"
OPENCLAW_REPO="https://github.com/getclaw/openclaw.git"
OPENCLAW_BRANCH="main"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "=========================================="
echo "OpenClaw Build and Setup"
echo "=========================================="
echo ""

# Check if Docker is available
if ! command -v docker &> /dev/null; then
    echo -e "${RED}Error: Docker is not installed${NC}"
    echo "Please run ./scripts/02-docker-install.sh first"
    exit 1
fi

# Test Docker permissions
if ! docker ps &> /dev/null; then
    echo -e "${RED}Error: Cannot run Docker commands${NC}"
    echo "Please ensure:"
    echo "  1. Docker service is running"
    echo "  2. Your user is in the docker group"
    echo "  3. You've logged out and back in after adding to docker group"
    echo ""
    echo "Try: sudo docker ps"
    exit 1
fi

echo -e "${GREEN}✓ Docker is available${NC}"

# Create OpenClaw directory
echo ""
echo -e "${YELLOW}Setting up OpenClaw directory...${NC}"

mkdir -p "$OPENCLAW_DIR"
cd "$OPENCLAW_DIR"

echo -e "${GREEN}✓ Directory created: $OPENCLAW_DIR${NC}"

# Check if git repo exists
if [ -d "$OPENCLAW_DIR/.git" ]; then
    echo ""
    echo -e "${YELLOW}OpenClaw repository already exists${NC}"
    read -p "Pull latest changes? (y/n): " pull_changes
    if [[ "$pull_changes" == "y" ]]; then
        git pull origin "$OPENCLAW_BRANCH"
        echo -e "${GREEN}✓ Repository updated${NC}"
    fi
else
    echo ""
    echo -e "${YELLOW}Cloning OpenClaw repository...${NC}"
    git clone -b "$OPENCLAW_BRANCH" "$OPENCLAW_REPO" .
    echo -e "${GREEN}✓ Repository cloned${NC}"
fi

# Copy deployment files from local if they exist
if [ -f "../docker-compose.yml" ]; then
    echo ""
    echo -e "${YELLOW}Copying deployment files...${NC}"
    cp ../docker-compose.yml .
    cp ../Dockerfile . 2>/dev/null || true
    cp ../.env . 2>/dev/null || true
    echo -e "${GREEN}✓ Deployment files copied${NC}"
fi

# Create .env file if it doesn't exist
if [ ! -f .env ]; then
    echo ""
    echo -e "${YELLOW}Creating .env configuration file...${NC}"

    cat > .env <<EOF
# OpenClaw Environment Configuration
# Generated: $(date)

# Gateway Configuration
GATEWAY_PORT=18789
GATEWAY_HOST=0.0.0.0

# Data Persistence
DATA_DIR=./data
LOGS_DIR=./logs

# Claude API Configuration
ANTHROPIC_API_KEY=

# LLM Provider Configuration
# Options: anthropic, openai, ollama
LLM_PROVIDER=anthropic

# OpenAI Configuration (if using OpenAI)
OPENAI_API_KEY=

# Ollama Configuration (if using Ollama)
OLLAMA_HOST=http://localhost:11434
OLLAMA_MODEL=llama2

# Telegram Configuration
TELEGRAM_BOT_TOKEN=
TELEGRAM_ENABLED=false

# Discord Configuration
DISCORD_BOT_TOKEN=
DISCORD_ENABLED=false

# Security
ADMIN_PASSWORD=

# Logging
LOG_LEVEL=info

# Jetson Optimization
NVIDIA_VISIBLE_DEVICES=all
NVIDIA_DRIVER_CAPABILITIES=compute,utility
EOF

    echo -e "${GREEN}✓ .env file created${NC}"
    echo -e "${YELLOW}Please edit .env and add your API keys${NC}"
else
    echo -e "${GREEN}✓ .env file already exists${NC}"
fi

# Create data directories
echo ""
echo -e "${YELLOW}Creating data directories...${NC}"

mkdir -p data logs

echo -e "${GREEN}✓ Data directories created${NC}"

# Build Docker image
echo ""
echo -e "${YELLOW}Building OpenClaw Docker image...${NC}"
echo "This may take 10-20 minutes on Jetson Nano..."
echo ""

if [ -f "Dockerfile" ]; then
    docker build -t openclaw:latest .
    echo -e "${GREEN}✓ Docker image built${NC}"
else
    echo -e "${YELLOW}No Dockerfile found, pulling pre-built image...${NC}"
    # Try to pull a pre-built image if available
    docker pull getclaw/openclaw:latest || true
    docker tag getclaw/openclaw:latest openclaw:latest 2>/dev/null || true
fi

# Display status
echo ""
echo "=========================================="
echo -e "${GREEN}OpenClaw build complete!${NC}"
echo "=========================================="
echo ""
echo "Installation directory: $OPENCLAW_DIR"
echo ""
echo "Configuration:"
echo "  - Edit .env file to add your API keys"
echo "  - Configure channels using ./scripts/04-configure-channels.sh"
echo ""
echo "Next steps:"
echo "  1. Edit $OPENCLAW_DIR/.env and add required API keys"
echo "  2. Run: docker-compose up -d"
echo "  3. Check status: docker-compose ps"
echo "  4. View logs: docker-compose logs -f"
echo "  5. Configure channels: ./scripts/04-configure-channels.sh"
echo ""
echo "Gateway will be available at: http://$(hostname -I | awk '{print $1}'):18789"
