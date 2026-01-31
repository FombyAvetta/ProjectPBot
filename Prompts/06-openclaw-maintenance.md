# OpenClaw Jetson Maintenance and Troubleshooting

## Objective
Maintain, update, and troubleshoot OpenClaw running on Jetson Nano.

## Target Device
- Host: 192.168.50.69
- User: john
- Device: NVIDIA Jetson Nano 8GB

## Daily Operations

### Check Status
```bash
ssh john@192.168.50.69 << 'EOF'
echo "=== Container Status ==="
docker ps -a --filter name=openclaw

echo ""
echo "=== Resource Usage ==="
docker stats --no-stream openclaw 2>/dev/null || echo "Container not running"

echo ""
echo "=== System Resources ==="
free -h
df -h /

echo ""
echo "=== Recent Logs ==="
docker logs --tail 20 openclaw 2>&1
EOF
```

### View Live Logs
```bash
ssh john@192.168.50.69 "docker logs -f openclaw"
```

### Restart Gateway
```bash
ssh john@192.168.50.69 "cd ~/openclaw && docker compose restart openclaw-gateway"
```

## Updating OpenClaw

### Update to Latest Version
```bash
ssh john@192.168.50.69 << 'EOF'
cd ~/openclaw

echo "Stopping OpenClaw..."
docker compose down

echo "Removing old image..."
docker rmi openclaw-jetson:local 2>/dev/null || true

echo "Rebuilding with latest code..."
docker compose build --no-cache

echo "Starting OpenClaw..."
docker compose up -d openclaw-gateway

echo "Update complete!"
docker logs -f openclaw
EOF
```

### Update Only (Keep Cache)
```bash
ssh john@192.168.50.69 << 'EOF'
cd ~/openclaw
docker compose down
docker compose build
docker compose up -d openclaw-gateway
EOF
```

## Troubleshooting

### Container Won't Start

#### Check logs for errors
```bash
ssh john@192.168.50.69 "docker logs openclaw 2>&1 | tail -100"
```

#### Check if port is in use
```bash
ssh john@192.168.50.69 "sudo netstat -tlnp | grep 18789"
```

#### Check Docker daemon
```bash
ssh john@192.168.50.69 "sudo systemctl status docker"
```

#### Restart Docker daemon
```bash
ssh john@192.168.50.69 "sudo systemctl restart docker && cd ~/openclaw && docker compose up -d"
```

### Out of Memory Issues

#### Check memory usage
```bash
ssh john@192.168.50.69 "free -h && docker stats --no-stream"
```

#### Add swap space
```bash
ssh john@192.168.50.69 << 'EOF'
# Check current swap
swapon --show

# Create 4GB swap file if none exists
if [ ! -f /swapfile ]; then
    sudo fallocate -l 4G /swapfile
    sudo chmod 600 /swapfile
    sudo mkswap /swapfile
    sudo swapon /swapfile
    echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
    echo "Swap file created"
fi

free -h
EOF
```

#### Limit container memory
```bash
# Edit docker-compose.yml to add memory limits
ssh john@192.168.50.69 << 'EOF'
cd ~/openclaw
cat >> docker-compose.override.yml << 'OVERRIDE'
version: '3.8'
services:
  openclaw-gateway:
    deploy:
      resources:
        limits:
          memory: 4G
        reservations:
          memory: 1G
OVERRIDE

docker compose down
docker compose up -d
EOF
```

### Disk Space Issues

#### Check disk usage
```bash
ssh john@192.168.50.69 << 'EOF'
echo "=== Disk Usage ==="
df -h

echo ""
echo "=== Docker Disk Usage ==="
docker system df

echo ""
echo "=== Large Directories ==="
du -sh /var/lib/docker/* 2>/dev/null | sort -rh | head -10
EOF
```

#### Clean up Docker
```bash
ssh john@192.168.50.69 << 'EOF'
echo "Cleaning Docker system..."
docker system prune -f
docker volume prune -f
docker image prune -a -f

echo ""
echo "Disk usage after cleanup:"
df -h /
EOF
```

### Network Issues

#### Test connectivity
```bash
ssh john@192.168.50.69 << 'EOF'
echo "=== Network Interfaces ==="
ip addr show

echo ""
echo "=== Gateway Port ==="
curl -s http://localhost:18789/health || echo "Gateway not responding"

echo ""
echo "=== DNS Resolution ==="
nslookup api.anthropic.com || echo "DNS issues detected"
EOF
```

#### Check firewall
```bash
ssh john@192.168.50.69 << 'EOF'
echo "=== UFW Status ==="
sudo ufw status

# Allow OpenClaw port if UFW is active
# sudo ufw allow 18789/tcp
EOF
```

### API Key Issues

#### Verify API key is set
```bash
ssh john@192.168.50.69 << 'EOF'
cd ~/openclaw
echo "Checking .env file..."
grep -v '^#' .env | grep -E "API_KEY|TOKEN" | sed 's/=.*/=***REDACTED***/'
EOF
```

#### Test API connectivity from container
```bash
ssh john@192.168.50.69 << 'EOF'
docker exec openclaw sh -c 'curl -s https://api.anthropic.com/v1/messages -H "x-api-key: $ANTHROPIC_API_KEY" -H "content-type: application/json" -d "{}" 2>&1 | head -5'
EOF
```

### Channel Connection Issues

#### List channels
```bash
ssh john@192.168.50.69 "cd ~/openclaw && docker compose run --rm openclaw-cli channels list"
```

#### Re-authenticate WhatsApp
```bash
ssh -t john@192.168.50.69 "cd ~/openclaw && docker compose run --rm openclaw-cli channels login --channel whatsapp"
```

#### Remove and re-add channel
```bash
ssh john@192.168.50.69 << 'EOF'
cd ~/openclaw
docker compose run --rm openclaw-cli channels remove --channel telegram
docker compose run --rm openclaw-cli channels add --channel telegram --token "YOUR_BOT_TOKEN"
docker compose restart openclaw-gateway
EOF
```

## Backup and Restore

### Backup Configuration
```bash
ssh john@192.168.50.69 << 'EOF'
BACKUP_DIR="$HOME/openclaw-backups/$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"

echo "Backing up configuration..."
cp -r ~/.openclaw "$BACKUP_DIR/openclaw-config"
cp ~/openclaw/.env "$BACKUP_DIR/env-backup"
cp ~/openclaw/docker-compose.yml "$BACKUP_DIR/"

echo "Backup created at: $BACKUP_DIR"
ls -la "$BACKUP_DIR"
EOF
```

### Restore Configuration
```bash
ssh john@192.168.50.69 << 'EOF'
# Replace BACKUP_DATE with actual backup folder name
BACKUP_DIR="$HOME/openclaw-backups/BACKUP_DATE"

if [ -d "$BACKUP_DIR" ]; then
    echo "Stopping OpenClaw..."
    cd ~/openclaw && docker compose down
    
    echo "Restoring configuration..."
    cp -r "$BACKUP_DIR/openclaw-config/"* ~/.openclaw/
    cp "$BACKUP_DIR/env-backup" ~/openclaw/.env
    
    echo "Starting OpenClaw..."
    docker compose up -d openclaw-gateway
    
    echo "Restore complete!"
else
    echo "Backup directory not found: $BACKUP_DIR"
fi
EOF
```

### Export Docker Volumes
```bash
ssh john@192.168.50.69 << 'EOF'
BACKUP_FILE="$HOME/openclaw-volumes-$(date +%Y%m%d).tar.gz"

echo "Exporting Docker volumes..."
docker run --rm \
    -v openclaw_openclaw-config:/config \
    -v openclaw_openclaw-workspace:/workspace \
    -v $HOME:/backup \
    arm64v8/alpine \
    tar czf /backup/$(basename $BACKUP_FILE) /config /workspace

echo "Volume backup created: $BACKUP_FILE"
EOF
```

## Performance Monitoring

### Create monitoring script
```bash
ssh john@192.168.50.69 << 'EOF'
cat > ~/openclaw/monitor.sh << 'SCRIPT'
#!/bin/bash
while true; do
    clear
    echo "=== OpenClaw Monitor - $(date) ==="
    echo ""
    docker stats --no-stream openclaw 2>/dev/null || echo "Container not running"
    echo ""
    echo "=== System Resources ==="
    free -h | head -2
    echo ""
    echo "=== Recent Logs ==="
    docker logs --tail 5 openclaw 2>&1
    echo ""
    echo "Press Ctrl+C to exit"
    sleep 5
done
SCRIPT
chmod +x ~/openclaw/monitor.sh
echo "Monitor script created: ~/openclaw/monitor.sh"
EOF
```

### Run monitoring
```bash
ssh -t john@192.168.50.69 "~/openclaw/monitor.sh"
```

## System Maintenance

### Reboot Jetson (with auto-start)
```bash
ssh john@192.168.50.69 "sudo reboot"

# OpenClaw should auto-restart due to restart: unless-stopped policy
# Wait 2-3 minutes, then check:
ssh john@192.168.50.69 "docker ps | grep openclaw"
```

### Update Jetson OS
```bash
ssh john@192.168.50.69 << 'EOF'
sudo apt-get update
sudo apt-get upgrade -y
sudo apt-get autoremove -y

# Reboot if kernel was updated
# sudo reboot
EOF
```

### Check Jetson health
```bash
ssh john@192.168.50.69 << 'EOF'
echo "=== Jetson Info ==="
cat /etc/nv_tegra_release 2>/dev/null || echo "Tegra release info not found"

echo ""
echo "=== Temperature ==="
cat /sys/devices/virtual/thermal/thermal_zone*/temp 2>/dev/null | while read temp; do
    echo "$(echo "scale=1; $temp/1000" | bc)°C"
done

echo ""
echo "=== CPU Usage ==="
top -bn1 | head -5

echo ""
echo "=== Uptime ==="
uptime
EOF
```

## Quick Reference Commands

| Task | Command |
|------|---------|
| Start | `ssh john@192.168.50.69 "~/openclaw/start.sh"` |
| Stop | `ssh john@192.168.50.69 "~/openclaw/stop.sh"` |
| Logs | `ssh john@192.168.50.69 "~/openclaw/logs.sh"` |
| Status | `ssh john@192.168.50.69 "~/openclaw/status.sh"` |
| Rebuild | `ssh john@192.168.50.69 "~/openclaw/rebuild.sh"` |
| Shell | `ssh john@192.168.50.69 "docker exec -it openclaw /bin/bash"` |
| CLI | `ssh -t john@192.168.50.69 "cd ~/openclaw && docker compose run --rm openclaw-cli"` |

## Expected Outcomes
- Ability to diagnose and fix common issues
- Backup and restore procedures documented
- Performance monitoring available
- System maintenance routines established
