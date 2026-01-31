#!/bin/bash
#
# 01-ssh-setup.sh
# SSH connectivity setup and verification for Jetson Nano deployment
#

set -e

# Configuration
JETSON_HOST="192.168.50.69"
JETSON_USER="john"
JETSON_ADDR="${JETSON_USER}@${JETSON_HOST}"
SSH_CONFIG_FILE="$HOME/.ssh/config"
SYSTEM_INFO_FILE="./jetson-system-info.txt"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "=========================================="
echo "OpenClaw Jetson SSH Setup"
echo "=========================================="
echo ""

# Test SSH connectivity
echo -e "${YELLOW}Testing SSH connection to ${JETSON_ADDR}...${NC}"
if ssh -o ConnectTimeout=5 -o BatchMode=yes "${JETSON_ADDR}" "echo 'SSH connection successful'" 2>/dev/null; then
    echo -e "${GREEN}✓ SSH connection successful${NC}"
else
    echo -e "${RED}✗ SSH connection failed${NC}"
    echo ""
    echo "Please ensure:"
    echo "  1. Jetson Nano is powered on and connected to network"
    echo "  2. SSH is enabled on the Jetson"
    echo "  3. You have SSH keys set up or can authenticate with password"
    echo ""
    read -p "Would you like to set up SSH key authentication? (y/n): " setup_keys

    if [[ "$setup_keys" == "y" || "$setup_keys" == "Y" ]]; then
        echo ""
        echo "Setting up SSH key authentication..."

        # Check if SSH key exists
        if [ ! -f "$HOME/.ssh/id_rsa.pub" ] && [ ! -f "$HOME/.ssh/id_ed25519.pub" ]; then
            echo "No SSH key found. Generating new ED25519 key..."
            ssh-keygen -t ed25519 -f "$HOME/.ssh/id_ed25519" -N ""
            KEY_FILE="$HOME/.ssh/id_ed25519.pub"
        elif [ -f "$HOME/.ssh/id_ed25519.pub" ]; then
            KEY_FILE="$HOME/.ssh/id_ed25519.pub"
        else
            KEY_FILE="$HOME/.ssh/id_rsa.pub"
        fi

        echo "Copying SSH key to Jetson..."
        ssh-copy-id -i "$KEY_FILE" "${JETSON_ADDR}"

        echo -e "${GREEN}✓ SSH key installed${NC}"
    else
        echo "Skipping SSH key setup. You'll need to enter password for each connection."
        exit 1
    fi
fi

# Gather system information
echo ""
echo -e "${YELLOW}Gathering Jetson system information...${NC}"

cat > "$SYSTEM_INFO_FILE" << 'EOF'
========================================
Jetson Nano System Information
========================================
Generated: $(date)

EOF

# Append system info
ssh "${JETSON_ADDR}" bash << 'REMOTE_EOF' >> "$SYSTEM_INFO_FILE"
echo "Hostname: $(hostname)"
echo "Architecture: $(uname -m)"
echo "Kernel: $(uname -r)"
echo ""
echo "--- CPU Info ---"
cat /proc/cpuinfo | grep "model name" | head -1
echo "CPU Cores: $(nproc)"
echo ""
echo "--- Memory Info ---"
free -h
echo ""
echo "--- Disk Space ---"
df -h /
echo ""
echo "--- Docker Status ---"
if command -v docker &> /dev/null; then
    echo "Docker installed: $(docker --version)"
    echo "Docker Compose: $(docker-compose --version 2>/dev/null || echo 'Not installed')"
else
    echo "Docker: Not installed"
fi
echo ""
echo "--- Network Info ---"
ip addr show | grep -A 2 "state UP"
echo ""
echo "--- CUDA/Jetson Info ---"
if [ -f /etc/nv_tegra_release ]; then
    echo "Jetson Release:"
    cat /etc/nv_tegra_release
fi
if command -v jetson_clocks &> /dev/null; then
    echo "Jetson Clocks available: Yes"
fi
REMOTE_EOF

echo -e "${GREEN}✓ System information saved to ${SYSTEM_INFO_FILE}${NC}"
echo ""
cat "$SYSTEM_INFO_FILE"

# Check/Create SSH config entry
echo ""
read -p "Would you like to add a SSH config entry for easy access? (y/n): " add_config

if [[ "$add_config" == "y" || "$add_config" == "Y" ]]; then
    # Check if entry already exists
    if grep -q "Host jetson" "$SSH_CONFIG_FILE" 2>/dev/null; then
        echo -e "${YELLOW}SSH config entry already exists${NC}"
    else
        echo "Adding SSH config entry..."
        mkdir -p "$HOME/.ssh"
        cat >> "$SSH_CONFIG_FILE" << EOF

# Jetson Nano - OpenClaw Deployment
Host jetson
    HostName ${JETSON_HOST}
    User ${JETSON_USER}
    ForwardAgent yes
    ServerAliveInterval 60
    ServerAliveCountMax 3
EOF
        chmod 600 "$SSH_CONFIG_FILE"
        echo -e "${GREEN}✓ SSH config entry added${NC}"
        echo ""
        echo "You can now connect with: ssh jetson"
    fi
fi

echo ""
echo "=========================================="
echo -e "${GREEN}SSH setup complete!${NC}"
echo "=========================================="
echo ""
echo "Next steps:"
echo "  1. Review system information in ${SYSTEM_INFO_FILE}"
echo "  2. Run ./scripts/02-docker-install.sh to install Docker"
echo "  3. Run ./deploy.sh to deploy OpenClaw"
