#!/bin/bash
#
# 02-docker-install.sh
# Docker and Docker Compose installation for Jetson Nano
# This script is designed to run ON the Jetson Nano
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "=========================================="
echo "Docker Installation for Jetson Nano"
echo "=========================================="
echo ""

# Check if running on ARM64
ARCH=$(uname -m)
if [[ "$ARCH" != "aarch64" ]]; then
    echo -e "${YELLOW}Warning: Not running on ARM64 architecture (detected: $ARCH)${NC}"
    read -p "Continue anyway? (y/n): " continue
    if [[ "$continue" != "y" ]]; then
        exit 1
    fi
fi

# Check if Docker is already installed
if command -v docker &> /dev/null; then
    echo -e "${GREEN}Docker is already installed: $(docker --version)${NC}"
    read -p "Reinstall Docker? (y/n): " reinstall
    if [[ "$reinstall" != "y" ]]; then
        echo "Skipping Docker installation"
        SKIP_DOCKER=true
    fi
fi

# Install Docker
if [[ "$SKIP_DOCKER" != "true" ]]; then
    echo -e "${YELLOW}Installing Docker...${NC}"

    # Update package index
    sudo apt-get update

    # Install prerequisites
    sudo apt-get install -y \
        ca-certificates \
        curl \
        gnupg \
        lsb-release

    # Add Docker's official GPG key
    sudo mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

    # Set up the repository
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
      $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

    # Install Docker Engine
    sudo apt-get update
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    echo -e "${GREEN}✓ Docker installed${NC}"
fi

# Configure Docker daemon for Jetson
echo ""
echo -e "${YELLOW}Configuring Docker daemon...${NC}"

sudo mkdir -p /etc/docker

# Create daemon.json with Jetson-optimized settings
sudo tee /etc/docker/daemon.json > /dev/null <<EOF
{
  "default-runtime": "nvidia",
  "runtimes": {
    "nvidia": {
      "path": "nvidia-container-runtime",
      "runtimeArgs": []
    }
  },
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "storage-driver": "overlay2"
}
EOF

echo -e "${GREEN}✓ Docker daemon configured${NC}"

# Install Docker Compose standalone (in addition to plugin)
echo ""
echo -e "${YELLOW}Installing Docker Compose standalone...${NC}"

DOCKER_COMPOSE_VERSION="2.24.5"
sudo curl -L "https://github.com/docker/compose/releases/download/v${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

echo -e "${GREEN}✓ Docker Compose installed${NC}"

# Add current user to docker group
echo ""
echo -e "${YELLOW}Adding user to docker group...${NC}"

sudo usermod -aG docker $USER

echo -e "${GREEN}✓ User added to docker group${NC}"
echo -e "${YELLOW}Note: You need to log out and back in for group changes to take effect${NC}"

# Enable and start Docker
echo ""
echo -e "${YELLOW}Enabling Docker service...${NC}"

sudo systemctl enable docker
sudo systemctl restart docker

echo -e "${GREEN}✓ Docker service enabled and started${NC}"

# Install NVIDIA Container Runtime (if not already installed)
echo ""
echo -e "${YELLOW}Checking NVIDIA Container Runtime...${NC}"

if ! command -v nvidia-container-runtime &> /dev/null; then
    echo "Installing NVIDIA Container Runtime..."

    distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
    curl -s -L https://nvidia.github.io/nvidia-docker/gpgkey | sudo apt-key add -
    curl -s -L https://nvidia.github.io/nvidia-docker/$distribution/nvidia-docker.list | sudo tee /etc/apt/sources.list.d/nvidia-docker.list

    sudo apt-get update
    sudo apt-get install -y nvidia-container-runtime

    sudo systemctl restart docker
    echo -e "${GREEN}✓ NVIDIA Container Runtime installed${NC}"
else
    echo -e "${GREEN}✓ NVIDIA Container Runtime already installed${NC}"
fi

# Verify installation
echo ""
echo "=========================================="
echo "Verifying installation..."
echo "=========================================="
echo ""

echo "Docker version:"
docker --version

echo ""
echo "Docker Compose version:"
docker-compose --version

echo ""
echo "Docker info:"
sudo docker info | grep -A 5 "Runtimes"

echo ""
echo "Testing Docker with hello-world:"
sudo docker run --rm hello-world

echo ""
echo "=========================================="
echo -e "${GREEN}Docker installation complete!${NC}"
echo "=========================================="
echo ""
echo "IMPORTANT: Log out and back in for docker group changes to take effect"
echo ""
echo "Next steps:"
echo "  1. Log out and back in (or run: newgrp docker)"
echo "  2. Test docker without sudo: docker ps"
echo "  3. Run ./scripts/03-openclaw-build.sh to build OpenClaw"
