# Jetson Nano SSH Connection Setup

## Objective
Set up SSH connection to Jetson Nano and gather system information.

## Target Device
- Host: 192.168.50.69
- User: john
- Device: NVIDIA Jetson Nano 8GB

## Tasks

### 1. Test SSH Connection
```bash
ssh john@192.168.50.69 "echo 'Connection successful'"
```

### 2. Gather System Information
Connect to the Jetson and run the following commands to gather system info:

```bash
ssh john@192.168.50.69 << 'EOF'
echo "=== System Info ==="
uname -a
echo ""
echo "=== OS Release ==="
cat /etc/os-release
echo ""
echo "=== Memory ==="
free -h
echo ""
echo "=== Disk Space ==="
df -h
echo ""
echo "=== CPU Info ==="
cat /proc/cpuinfo | grep -E "model name|Hardware|CPU|processor" | head -10
echo ""
echo "=== NVIDIA/Tegra Info ==="
cat /etc/nv_tegra_release 2>/dev/null || echo "Not found"
echo ""
echo "=== Docker Version ==="
docker --version 2>/dev/null || echo "Docker not installed"
echo ""
echo "=== Docker Compose Version ==="
docker-compose --version 2>/dev/null || docker compose version 2>/dev/null || echo "Docker Compose not installed"
EOF
```

### 3. Set Up SSH Key (Optional but Recommended)
If password-less SSH is needed:

```bash
# Generate SSH key if not exists
[ -f ~/.ssh/id_rsa ] || ssh-keygen -t rsa -b 4096 -N "" -f ~/.ssh/id_rsa

# Copy key to Jetson
ssh-copy-id john@192.168.50.69
```

### 4. Create SSH Config Entry
Add to ~/.ssh/config for easier access:

```
Host jetson
    HostName 192.168.50.69
    User john
    IdentityFile ~/.ssh/id_rsa
```

Then you can simply use: `ssh jetson`

## Expected Outcomes
- Confirmed SSH connectivity to Jetson Nano
- System specifications documented
- Docker availability verified
- SSH config set up for easy access
