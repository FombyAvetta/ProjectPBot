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
│   ├── 05-qwen3-setup.sh         # Qwen3 local LLM setup
│   ├── 06-maintenance.sh         # Maintenance utilities
│   └── 07-benchmark-qwen3.sh     # Qwen3 performance testing
├── docker/
│   ├── Dockerfile                # ARM64-optimized container
│   ├── Dockerfile.qwen3          # Qwen3 service container
│   ├── docker-compose.yml        # Service definitions
│   ├── docker-entrypoint.sh      # Container entrypoint
│   ├── docker-entrypoint-qwen3.sh # Qwen3 entrypoint
│   └── .env.example              # Environment template
├── deploy.sh                     # Master deployment script
├── README.md                     # This file
└── QWEN3-GUIDE.md                # Comprehensive Qwen3 guide
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
- `LLM_PROVIDER` - anthropic, openai, ollama, or qwen3
- `ANTHROPIC_API_KEY` - Claude API key
- `OPENAI_API_KEY` - OpenAI API key (optional)
- `OLLAMA_HOST` - Ollama host for local models (optional)
- `QWEN3_HOST` - Qwen3 local LLM host (optional, see Qwen3 section)

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

## Local LLM with Qwen3 4B

### Overview

Qwen3 4B provides local, offline LLM inference on your Jetson Nano 8GB. This optional component gives you:

- **Completely offline operation** - No internet required for inference
- **Privacy** - All data stays on your device
- **Cost-effective** - Free after initial setup (no API fees)
- **Performance** - 10-15 tokens/second generation speed
- **Memory** - ~2.5GB model size, 2.8-3.5GB runtime memory

### Quick Setup

```bash
ssh john@192.168.50.69
cd openclaw
./scripts/05-qwen3-setup.sh
```

Interactive menu options:
1. **Download Model** - Download Qwen3 4B Q4_K_M GGUF (~2.5GB, 30-60 min)
2. **Build Service** - Build Docker image with llama.cpp (~20-30 min, one-time)
3. **Enable Qwen3** - Start the service
4. **Disable Qwen3** - Stop the service and free memory
5. **Test API** - Send test prompt and measure performance
6. **Configure Settings** - Tune performance parameters
7. **View Status** - Show current state and resource usage

### Using Qwen3 with OpenClaw

After setup, configure OpenClaw to use Qwen3:

```bash
# Edit .env file
nano ~/openclaw/.env

# Set LLM provider to qwen3
LLM_PROVIDER=qwen3

# Restart OpenClaw
docker compose restart gateway
```

Now all OpenClaw requests will use local Qwen3!

### Performance Profiles

Choose based on your needs:

**Profile 1: Minimal Memory (Stable)**
```bash
QWEN3_CONTEXT_LENGTH=1024
QWEN3_GPU_LAYERS=24
QWEN3_BATCH_SIZE=256
```
- Memory: ~2.2GB
- Speed: ~8-10 tok/s
- Best for: Running alongside other services

**Profile 2: Balanced (Recommended)**
```bash
QWEN3_CONTEXT_LENGTH=2048
QWEN3_GPU_LAYERS=32
QWEN3_BATCH_SIZE=512
```
- Memory: ~2.8GB
- Speed: ~10-12 tok/s
- Best for: Most use cases

**Profile 3: Maximum Performance**
```bash
QWEN3_CONTEXT_LENGTH=4096
QWEN3_GPU_LAYERS=99
QWEN3_BATCH_SIZE=1024
```
- Memory: ~4.5GB
- Speed: ~12-15 tok/s
- Best for: Dedicated Qwen3 use (risky on 8GB)

### Management Commands

**Enable/Disable via maintenance menu:**
```bash
./scripts/06-maintenance.sh
# Option 17: Enable Qwen3 Service
# Option 18: Disable Qwen3 Service
# Option 19: Qwen3 Status & Diagnostics
# Option 20: Qwen3 Performance Test
```

**Run performance benchmark:**
```bash
./scripts/07-benchmark-qwen3.sh
```

Measures:
- Cold start time
- First token latency
- Generation speed (tokens/sec)
- Context length scaling
- Memory usage under load
- Overall performance score

### When to Use Qwen3 vs Cloud LLMs

**Use Qwen3 for:**
- Privacy-sensitive tasks
- Offline/unreliable internet environments
- High-volume, simple tasks (summaries, Q&A, etc.)
- Development and testing
- Cost optimization

**Use Claude/GPT-4 for:**
- Complex reasoning tasks
- Long context (> 4K tokens)
- Latest information/knowledge
- Production critical paths
- Specialized domains

### Memory Considerations

**Safe Operating Ranges:**
- \> 4GB free: Can run any profile
- 3-4GB free: Use Profile 2 (Balanced)
- 2-3GB free: Use Profile 1 (Minimal)
- < 2GB free: Don't enable Qwen3

**Monitor memory:**
```bash
# Real-time monitoring
free -h

# Container stats
docker stats openclaw-qwen3

# Jetson-specific
tegrastats
```

### Comprehensive Guide

For detailed documentation including:
- Installation and configuration
- Performance tuning strategies
- Context length vs memory tradeoffs
- GPU layer optimization
- Troubleshooting common issues
- Comparison with cloud LLMs
- Advanced topics

See: **[QWEN3-GUIDE.md](QWEN3-GUIDE.md)**

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
