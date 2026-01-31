# OpenClaw Deployment for Jetson Nano

Automated deployment system for running OpenClaw on NVIDIA Jetson Nano 8GB.

## Overview

This repository contains all necessary scripts and configuration files to deploy OpenClaw to a Jetson Nano. The deployment process is split into two phases:

1. **Phase 1: Local Development** - Create and test deployment scripts locally
2. **Phase 2: Remote Deployment** - Deploy to Jetson Nano

## Prerequisites

### Local Machine (macOS/Linux)
- SSH client
- rsync
- Git

### Jetson Nano
- NVIDIA Jetson Nano 8GB
- JetPack 4.6+ installed
- SSH access enabled
- Network connectivity
- At least 10GB free disk space

## Quick Start

### 1. Configure SSH Access

First, set up SSH connectivity to your Jetson:

```bash
./scripts/01-ssh-setup.sh
```

This will:
- Test SSH connection
- Set up SSH keys (optional)
- Gather system information
- Create SSH config entry

### 2. Deploy to Jetson

Run the master deployment script:

```bash
./deploy.sh
```

This will:
1. Transfer deployment files to Jetson
2. Install Docker (if needed)
3. Build OpenClaw container
4. Configure environment
5. Start services

### 3. Configure API Keys

SSH to the Jetson and edit the environment file:

```bash
ssh john@192.168.50.69
cd openclaw
nano .env
```

Add your API keys:
- `ANTHROPIC_API_KEY` - Get from https://console.anthropic.com/
- `TELEGRAM_BOT_TOKEN` - Get from @BotFather on Telegram
- `DISCORD_BOT_TOKEN` - Get from https://discord.com/developers/applications

Then restart:

```bash
docker-compose restart
```

### 4. Configure Channels

```bash
ssh john@192.168.50.69
cd openclaw
./scripts/04-configure-channels.sh
```

## Directory Structure

```
ProjectPBot/
├── scripts/
│   ├── 01-ssh-setup.sh           # SSH connectivity setup
│   ├── 02-docker-install.sh      # Docker installation
│   ├── 03-openclaw-build.sh      # OpenClaw build
│   ├── 04-configure-channels.sh  # Channel configuration
│   └── 06-maintenance.sh         # Maintenance utilities
├── docker/
│   ├── Dockerfile                # ARM64-optimized container
│   ├── docker-compose.yml        # Service definitions
│   ├── docker-entrypoint.sh      # Container entrypoint
│   └── .env.example              # Environment template
├── deploy.sh                     # Master deployment script
└── README.md                     # This file
```

## Scripts Reference

### 01-ssh-setup.sh
Sets up SSH connectivity to the Jetson Nano.

**Features:**
- Tests SSH connection
- Optionally sets up SSH keys
- Gathers system information
- Creates SSH config entry

**Usage:**
```bash
./scripts/01-ssh-setup.sh
```

### 02-docker-install.sh
Installs Docker and Docker Compose on the Jetson.

**Features:**
- Installs Docker Engine
- Installs Docker Compose
- Configures Docker daemon for Jetson
- Installs NVIDIA Container Runtime
- Adds user to docker group

**Usage (run on Jetson):**
```bash
./scripts/02-docker-install.sh
```

### 03-openclaw-build.sh
Builds and configures OpenClaw.

**Features:**
- Creates OpenClaw directory
- Clones/updates repository
- Creates .env file
- Builds Docker image
- Creates data directories

**Usage (run on Jetson):**
```bash
./scripts/03-openclaw-build.sh
```

### 04-configure-channels.sh
Interactive channel configuration utility.

**Features:**
- Configure Telegram bot
- Configure Discord bot
- List active channels
- Test connections
- View logs

**Usage (run on Jetson):**
```bash
./scripts/04-configure-channels.sh
```

### 06-maintenance.sh
Maintenance and troubleshooting utilities.

**Features:**
- Check service status
- View logs and errors
- Monitor resources
- Start/stop/restart services
- Update OpenClaw
- Backup/restore configuration
- Run diagnostics

**Usage (run on Jetson):**
```bash
./scripts/06-maintenance.sh
```

### deploy.sh
Master deployment orchestrator (runs locally).

**Features:**
- Validates SSH connectivity
- Transfers deployment files
- Executes remote installation
- Configures OpenClaw
- Starts services

**Usage:**
```bash
./deploy.sh                # Full deployment
./deploy.sh --transfer-only # Only transfer files
./deploy.sh --status       # Check status
./deploy.sh --logs         # View logs
./deploy.sh --help         # Show help
```

## Configuration

### Environment Variables

Edit `.env` on the Jetson to configure:

#### Gateway
- `GATEWAY_PORT` - Port for web interface (default: 18789)
- `GATEWAY_HOST` - Bind address (default: 0.0.0.0)

#### LLM Provider
- `LLM_PROVIDER` - anthropic, openai, or ollama
- `ANTHROPIC_API_KEY` - Claude API key
- `OPENAI_API_KEY` - OpenAI API key (optional)
- `OLLAMA_HOST` - Ollama host for local models (optional)

#### Channels
- `TELEGRAM_BOT_TOKEN` - Telegram bot token
- `TELEGRAM_ENABLED` - Enable/disable Telegram
- `DISCORD_BOT_TOKEN` - Discord bot token
- `DISCORD_ENABLED` - Enable/disable Discord

#### Security
- `ADMIN_PASSWORD` - Admin interface password
- `JWT_SECRET` - JWT signing secret

#### Logging
- `LOG_LEVEL` - debug, info, warning, error, critical

### Docker Configuration

The `docker-compose.yml` defines:
- Gateway service with NVIDIA runtime
- Port mappings
- Volume mounts for data persistence
- Environment variable injection
- Health checks

### Dockerfile

ARM64-optimized container based on NVIDIA L4T:
- Python 3.8 runtime
- OpenClaw dependencies
- CUDA support
- Health checks

## Usage

### Starting Services

```bash
ssh john@192.168.50.69
cd openclaw
docker-compose up -d
```

### Stopping Services

```bash
docker-compose down
```

### Viewing Logs

```bash
docker-compose logs -f
```

### Checking Status

```bash
docker-compose ps
```

### Restarting After Configuration Changes

```bash
docker-compose restart
```

### Accessing Gateway

Open browser to: http://192.168.50.69:18789

## Maintenance

### Update OpenClaw

```bash
ssh john@192.168.50.69
cd openclaw
./scripts/06-maintenance.sh
# Select option 9: Update OpenClaw
```

### Backup Configuration

```bash
./scripts/06-maintenance.sh
# Select option 10: Backup Configuration
```

### View System Resources

```bash
./scripts/06-maintenance.sh
# Select option 4: System Resource Usage
```

### Troubleshooting

```bash
./scripts/06-maintenance.sh
# Select option 13: Run Diagnostics
```

## Troubleshooting

### Can't connect via SSH

1. Verify Jetson is powered on and connected to network
2. Check IP address: `ip addr show`
3. Ensure SSH is enabled: `sudo systemctl status ssh`
4. Run `./scripts/01-ssh-setup.sh` to configure keys

### Docker permission denied

You need to log out and back in after being added to docker group:
```bash
newgrp docker
# or logout and login again
```

### Container fails to start

Check logs:
```bash
docker-compose logs
```

Common issues:
- Missing API keys in .env
- Port 18789 already in use
- Insufficient disk space

### NVIDIA runtime not available

Reinstall NVIDIA Container Runtime:
```bash
./scripts/02-docker-install.sh
```

### Gateway not accessible

1. Check if container is running: `docker-compose ps`
2. Check logs: `docker-compose logs gateway`
3. Verify port binding: `netstat -tulpn | grep 18789`
4. Check firewall rules

## Remote Access

### From Local Machine

View status:
```bash
./deploy.sh --status
```

View logs:
```bash
./deploy.sh --logs
```

Direct SSH commands:
```bash
ssh john@192.168.50.69 'cd openclaw && docker-compose ps'
```

### SSH Config

After running `01-ssh-setup.sh`, you can use:
```bash
ssh jetson
```

## Performance Optimization

### Jetson Power Mode

Set maximum performance:
```bash
sudo nvpmodel -m 0
sudo jetson_clocks
```

### Monitor Resources

```bash
tegrastats
```

Or use jtop:
```bash
sudo pip3 install jetson-stats
sudo jtop
```

## Security Considerations

1. Change default admin password in `.env`
2. Use strong API keys
3. Keep Jetson and Docker updated
4. Use firewall rules to restrict access
5. Enable SSH key authentication only
6. Don't commit `.env` to git

## Updates

### Update Deployment Scripts

On local machine:
```bash
cd /Users/johnfomby/Documents/CodeProjects/ProjectPBot
git pull
./deploy.sh --transfer-only
```

### Update OpenClaw on Jetson

```bash
ssh john@192.168.50.69
cd openclaw
git pull origin main
docker-compose build
docker-compose up -d
```

## Support

For OpenClaw issues:
- GitHub: https://github.com/getclaw/openclaw
- Documentation: https://docs.getclaw.io

For Jetson issues:
- NVIDIA Developer Forums: https://forums.developer.nvidia.com/c/agx-autonomous-machines/jetson-embedded-systems/

## License

This deployment system is provided as-is for educational and development purposes.

## Target Configuration

- **Device**: NVIDIA Jetson Nano 8GB
- **Remote Host**: 192.168.50.69
- **Remote User**: john
- **Remote Directory**: ~/openclaw
- **Gateway Port**: 18789

---

**Note**: This is a development deployment. For production use, consider:
- SSL/TLS certificates
- Reverse proxy (nginx)
- Database backup automation
- Monitoring and alerting
- High availability configuration
