# OpenClaw Jetson Nano Deployment Prompts

This folder contains Claude Code prompts for deploying and managing OpenClaw on a Jetson Nano 8GB via Docker.

## Target Configuration
- **Device**: NVIDIA Jetson Nano 8GB
- **Host**: 192.168.50.69
- **User**: john
- **Method**: Docker containerized deployment

## Prompt Files

| File | Description |
|------|-------------|
| `01-jetson-ssh-setup.md` | SSH connection setup and system info gathering |
| `02-jetson-docker-install.md` | Docker Engine installation on Jetson |
| `03-openclaw-docker-build.md` | OpenClaw Docker image build and deployment |
| `04-openclaw-configure-channels.md` | Channel configuration (Telegram, Discord, WhatsApp) |
| `05-openclaw-master-deployment.md` | One-command complete deployment script |
| `06-openclaw-maintenance.md` | Troubleshooting and maintenance procedures |

## Quick Start

### Option 1: Step-by-Step Deployment
Follow the prompts in order (01 → 06) for a guided deployment.

### Option 2: One-Command Deployment
Use the master deployment script from `05-openclaw-master-deployment.md`:

```bash
# Set your API key
export ANTHROPIC_API_KEY="sk-ant-your-key-here"

# Deploy (run from your Mac)
ssh john@192.168.50.69 "ANTHROPIC_API_KEY='$ANTHROPIC_API_KEY' bash -s" < 05-master-script.sh
```

## Prerequisites

1. **Jetson Nano** with network connectivity
2. **SSH access** to the Jetson (john@192.168.50.69)
3. **Anthropic API Key** (or other LLM provider)

## Post-Deployment

After deployment, access OpenClaw at:
```
http://192.168.50.69:18789/?token=YOUR_GATEWAY_TOKEN
```

## Architecture

```
┌─────────────────────────────────────────────────────┐
│                   Your Network                       │
├─────────────────────────────────────────────────────┤
│                                                      │
│  ┌──────────────┐         ┌──────────────────────┐  │
│  │   Your Mac   │   SSH   │    Jetson Nano       │  │
│  │              │ ──────► │    192.168.50.69     │  │
│  │  (Control)   │         │                      │  │
│  └──────────────┘         │  ┌────────────────┐  │  │
│                           │  │    Docker      │  │  │
│  ┌──────────────┐         │  │  ┌──────────┐  │  │  │
│  │   Phone      │         │  │  │ OpenClaw │  │  │  │
│  │  (Telegram)  │ ◄─────────►│  │ Gateway  │  │  │  │
│  └──────────────┘  Bot API │  │  │ :18789   │  │  │  │
│                           │  │  └──────────┘  │  │  │
│  ┌──────────────┐         │  └────────────────┘  │  │
│  │   Browser    │  HTTP   │                      │  │
│  │  (Control UI)│ ◄───────────────────────────────  │
│  └──────────────┘         └──────────────────────┘  │
│                                                      │
└─────────────────────────────────────────────────────┘
```

## Resource Requirements

| Resource | Minimum | Recommended |
|----------|---------|-------------|
| RAM | 1 GB | 2+ GB |
| Disk | 500 MB | 2+ GB |
| CPU | 1 core | 2+ cores |

Your Jetson Nano 8GB exceeds all requirements.

## Useful Commands

```bash
# SSH to Jetson
ssh john@192.168.50.69

# Start OpenClaw
ssh john@192.168.50.69 "~/openclaw/start.sh"

# Stop OpenClaw
ssh john@192.168.50.69 "~/openclaw/stop.sh"

# View logs
ssh john@192.168.50.69 "docker logs -f openclaw"

# Check status
ssh john@192.168.50.69 "~/openclaw/status.sh"

# Run CLI commands
ssh -t john@192.168.50.69 "cd ~/openclaw && docker compose run --rm openclaw-cli status"

# Rebuild
ssh john@192.168.50.69 "~/openclaw/rebuild.sh"
```

## Channels Supported

- Telegram (easiest setup)
- Discord
- WhatsApp (requires QR code scan)
- Signal
- Slack
- iMessage (requires macOS device)

## Security Notes

1. **Gateway Token**: Always use a strong, random token
2. **API Keys**: Store in .env file, never commit to git
3. **Network**: OpenClaw listens on LAN by default
4. **DM Pairing**: Enable to prevent unauthorized access

## Troubleshooting

See `06-openclaw-maintenance.md` for detailed troubleshooting procedures.

Common issues:
- **Container won't start**: Check logs with `docker logs openclaw`
- **Out of memory**: Add swap space (documented in maintenance guide)
- **Channel disconnected**: Re-authenticate using CLI
- **API errors**: Verify API key in .env file

## References

- [OpenClaw Documentation](https://docs.openclaw.ai/)
- [OpenClaw GitHub](https://github.com/openclaw/openclaw)
- [OpenClaw Docker Guide](https://docs.openclaw.ai/install/docker)
- [Jetson Nano Documentation](https://developer.nvidia.com/embedded/jetson-nano)

---

*Created for ProjectPBot - OpenClaw on Jetson Nano deployment*
