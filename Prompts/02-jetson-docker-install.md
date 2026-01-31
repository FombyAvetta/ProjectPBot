# Install Docker on Jetson Nano

## Objective
Install and configure Docker and Docker Compose on the Jetson Nano for running OpenClaw.

## Target Device
- Host: 192.168.50.69
- User: john
- Device: NVIDIA Jetson Nano 8GB

## Tasks

### 1. Install Docker Engine
SSH into the Jetson and run:

```bash
ssh john@192.168.50.69 << 'EOF'
#!/bin/bash
set -e

echo "=== Updating system packages ==="
sudo apt-get update

echo "=== Installing prerequisites ==="
sudo apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    software-properties-common

echo "=== Adding Docker GPG key ==="
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

echo "=== Adding Docker repository ==="
echo "deb [arch=arm64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

echo "=== Installing Docker ==="
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

echo "=== Adding user to docker group ==="
sudo usermod -aG docker $USER

echo "=== Enabling Docker service ==="
sudo systemctl enable docker
sudo systemctl start docker

echo "=== Docker installation complete ==="
docker --version
EOF
```

### 2. Verify Docker Installation
```bash
ssh john@192.168.50.69 << 'EOF'
# Need to use newgrp or re-login for group changes
sudo docker run hello-world
sudo docker info | head -20
EOF
```

### 3. Install Docker Compose (if not included)
```bash
ssh john@192.168.50.69 << 'EOF'
# Check if docker compose plugin is available
if ! docker compose version 2>/dev/null; then
    echo "Installing Docker Compose standalone..."
    sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
fi

# Verify
docker compose version || docker-compose --version
EOF
```

### 4. Configure Docker for Jetson (Optional Optimizations)
```bash
ssh john@192.168.50.69 << 'EOF'
# Create Docker daemon config for better performance on Jetson
sudo mkdir -p /etc/docker
sudo tee /etc/docker/daemon.json << 'DAEMON'
{
    "storage-driver": "overlay2",
    "log-driver": "json-file",
    "log-opts": {
        "max-size": "10m",
        "max-file": "3"
    }
}
DAEMON

sudo systemctl restart docker
echo "Docker daemon configured"
EOF
```

## Verification Commands
```bash
ssh john@192.168.50.69 "docker --version && docker compose version && docker ps"
```

## Expected Outcomes
- Docker Engine installed and running
- Docker Compose available
- User added to docker group
- Docker service enabled on boot
