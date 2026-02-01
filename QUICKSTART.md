# OpenClaw Jetson Deployment - Quick Start Guide

## 🚀 Deploy in 3 Steps

### Step 1: Setup SSH (2 minutes)
```bash
./scripts/01-ssh-setup.sh
```
This tests connectivity and optionally sets up SSH keys.

### Step 2: Deploy Everything (20-30 minutes)
```bash
./deploy.sh
```
This transfers files, installs Docker, builds OpenClaw, and starts services.

### Step 3: Configure API Keys (2 minutes)
```bash
ssh john@192.168.50.69
cd openclaw
nano .env
# Add your ANTHROPIC_API_KEY
docker-compose restart
```

## ✅ Access Your Gateway

Open: http://192.168.50.69:18789

## 🤖 Add Channels

### Telegram
```bash
ssh john@192.168.50.69
cd openclaw
./scripts/04-configure-channels.sh
# Select option 1
```

### Discord
```bash
# Same menu, select option 2
```

## 🤖 Option: Local LLM with Qwen3 4B (Optional)

Want to run a local LLM for offline, private inference? Deploy Qwen3 4B!

### Quick Setup (30-60 minutes)
```bash
ssh john@192.168.50.69
cd openclaw
./scripts/05-qwen3-setup.sh
```

**Interactive menu:**
1. Download Model (~2.5GB, 30-60 min)
2. Build Service (one-time, 20-30 min)
3. Enable Qwen3 (start service)
5. Test API (verify it works)

### Use Qwen3 as Primary LLM
```bash
# Edit .env
nano ~/openclaw/.env

# Set provider
LLM_PROVIDER=qwen3

# Restart
docker compose restart
```

### Performance
- **Speed**: 10-15 tokens/second
- **Memory**: ~2.8-3.5GB (leave 4GB+ free)
- **Cost**: Free after setup
- **Privacy**: Complete offline operation

### Quick Commands
```bash
# Enable Qwen3
./scripts/06-maintenance.sh  # Option 17

# Disable Qwen3 (free memory)
./scripts/06-maintenance.sh  # Option 18

# Check status
./scripts/06-maintenance.sh  # Option 19

# Run benchmark
./scripts/07-benchmark-qwen3.sh
```

**Full Guide:** [QWEN3-GUIDE.md](QWEN3-GUIDE.md)

## 📊 Common Commands

### Check Status
```bash
./deploy.sh --status
```

### View Logs
```bash
./deploy.sh --logs
```

### Restart Services
```bash
ssh john@192.168.50.69
cd openclaw
docker-compose restart
```

### Maintenance Menu
```bash
ssh john@192.168.50.69
cd openclaw
./scripts/06-maintenance.sh
```

## 🔧 Troubleshooting

### Can't SSH?
```bash
ping 192.168.50.69
./scripts/01-ssh-setup.sh
```

### Docker Errors?
```bash
ssh john@192.168.50.69
cd openclaw
./scripts/06-maintenance.sh
# Select option 13: Run Diagnostics
```

### Container Won't Start?
```bash
ssh john@192.168.50.69
cd openclaw
docker-compose logs
```

Check that you have:
- ANTHROPIC_API_KEY set in .env
- Sufficient disk space (10GB+)
- Docker running: `docker ps`

## 📝 Configuration Files

### On Jetson: ~/openclaw/.env
```bash
ANTHROPIC_API_KEY=sk-ant-your-key-here
TELEGRAM_BOT_TOKEN=your-bot-token
DISCORD_BOT_TOKEN=your-bot-token
```

## 🎯 Next Steps

1. Configure channels: `./scripts/04-configure-channels.sh`
2. Test with messages to your bots
3. Monitor logs: `docker-compose logs -f`
4. Explore gateway UI: http://192.168.50.69:18789

## 📚 Full Documentation

See [README.md](README.md) for complete documentation.

## 🆘 Emergency Commands

### Stop Everything
```bash
ssh john@192.168.50.69
cd openclaw
docker-compose down
```

### Factory Reset
```bash
ssh john@192.168.50.69
cd openclaw
./scripts/06-maintenance.sh
# Select option 14 (WARNING: Deletes all data)
```

### Backup Before Changes
```bash
ssh john@192.168.50.69
cd openclaw
./scripts/06-maintenance.sh
# Select option 10: Backup Configuration
```

---

**Target System:**
- Device: NVIDIA Jetson Nano 8GB
- IP: 192.168.50.69
- User: john
- Directory: ~/openclaw
