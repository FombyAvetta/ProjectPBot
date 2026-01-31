# OpenClaw Jetson Deployment Checklist

Use this checklist to track your deployment progress.

## Pre-Deployment

### Local Setup
- [ ] Verify all files created: `./scripts/00-verify-setup.sh`
- [ ] Review configuration files
- [ ] Ensure Jetson is powered on and accessible
- [ ] Obtain necessary API keys:
  - [ ] Anthropic API key from https://console.anthropic.com/
  - [ ] Telegram bot token (optional)
  - [ ] Discord bot token (optional)

### Prerequisites Check
- [ ] SSH client available on local machine
- [ ] rsync installed on local machine
- [ ] Jetson Nano connected to network
- [ ] Know Jetson IP address: 192.168.50.69
- [ ] Know Jetson username: john
- [ ] Have Jetson password or SSH key

## Phase 1: SSH Setup (2 minutes)

- [ ] Run `./scripts/01-ssh-setup.sh`
- [ ] Test SSH connection succeeds
- [ ] Set up SSH keys (recommended)
- [ ] Review jetson-system-info.txt
- [ ] Verify SSH config entry created (optional)
- [ ] Can connect with: `ssh john@192.168.50.69`

### Expected Output
```
✓ SSH connection successful
✓ System information saved
✓ SSH config entry added
```

## Phase 2: File Transfer & Docker Install (10-15 minutes)

- [ ] Run `./deploy.sh`
- [ ] Confirm when prompted
- [ ] Wait for file transfer to complete
- [ ] Docker installation started (if needed)
- [ ] Docker installation completed
- [ ] No errors during installation

### Expected Output
```
✓ Prerequisites checked
✓ SSH connection successful
✓ Files transferred successfully
✓ Docker installation complete (or already installed)
```

## Phase 3: OpenClaw Build (15-20 minutes)

- [ ] OpenClaw build process started
- [ ] Docker image building (this takes time on Jetson)
- [ ] Repository cloned
- [ ] Dependencies installed
- [ ] Image build completed
- [ ] .env file created
- [ ] Data directories created

### Expected Output
```
✓ Repository cloned
✓ .env file created
✓ Data directories created
✓ Docker image built
```

## Phase 4: Configuration (5 minutes)

### Environment Configuration
- [ ] SSH to Jetson: `ssh john@192.168.50.69`
- [ ] Navigate to openclaw: `cd openclaw`
- [ ] Edit .env file: `nano .env`
- [ ] Add ANTHROPIC_API_KEY
- [ ] Configure other options as needed
- [ ] Save and exit (Ctrl+X, Y, Enter)
- [ ] Restart services: `docker-compose restart`

### Required Settings
```bash
ANTHROPIC_API_KEY=sk-ant-your-key-here
```

### Optional Settings
```bash
TELEGRAM_BOT_TOKEN=your-telegram-token
TELEGRAM_ENABLED=true

DISCORD_BOT_TOKEN=your-discord-token
DISCORD_ENABLED=true

ADMIN_PASSWORD=secure-password-here
```

## Phase 5: Service Startup (2 minutes)

- [ ] Services starting: `docker-compose up -d`
- [ ] Wait for containers to start (30 seconds)
- [ ] Check status: `docker-compose ps`
- [ ] Gateway container shows "Up"
- [ ] No restart loops
- [ ] Check logs: `docker-compose logs --tail=50`
- [ ] No critical errors in logs

### Expected Output
```
NAME                    STATUS
openclaw-gateway        Up (healthy)
```

## Phase 6: Access & Verification (2 minutes)

### Gateway Access
- [ ] Open browser to: http://192.168.50.69:18789
- [ ] Gateway UI loads
- [ ] No connection errors
- [ ] Health check: `curl http://192.168.50.69:18789/health`

### From Local Machine
- [ ] Check status: `./deploy.sh --status`
- [ ] View logs: `./deploy.sh --logs`
- [ ] Gateway accessible from local network

## Phase 7: Channel Configuration (10 minutes)

### Telegram Setup (Optional)
- [ ] SSH to Jetson
- [ ] Run: `./scripts/04-configure-channels.sh`
- [ ] Select option 1 (Configure Telegram Bot)
- [ ] Enter bot token
- [ ] Restart applied
- [ ] Send test message to bot
- [ ] Bot responds

### Discord Setup (Optional)
- [ ] Run: `./scripts/04-configure-channels.sh`
- [ ] Select option 2 (Configure Discord Bot)
- [ ] Enter bot token
- [ ] Restart applied
- [ ] Add bot to Discord server
- [ ] Send test message
- [ ] Bot responds

## Phase 8: Testing (5 minutes)

### Functional Tests
- [ ] Send message to configured channel
- [ ] Bot receives message
- [ ] Claude processes request
- [ ] Bot sends response
- [ ] Response is coherent
- [ ] Conversation context maintained

### System Tests
- [ ] Check resource usage: `docker stats`
- [ ] CPU usage reasonable (<80%)
- [ ] Memory usage reasonable (<6GB)
- [ ] No memory leaks
- [ ] Logs show normal operation
- [ ] No error messages

## Phase 9: Documentation & Backup (5 minutes)

### Document Configuration
- [ ] Note API keys used (store securely)
- [ ] Note bot tokens (store securely)
- [ ] Note admin password (store securely)
- [ ] Document any custom settings
- [ ] Save configuration reference

### Create Initial Backup
- [ ] Run: `./scripts/06-maintenance.sh`
- [ ] Select option 10 (Backup Configuration)
- [ ] Verify backup created
- [ ] Note backup location
- [ ] Test backup file exists

## Post-Deployment

### Monitoring Setup
- [ ] Bookmark gateway URL: http://192.168.50.69:18789
- [ ] Set up log monitoring (optional)
- [ ] Configure alerts (optional)
- [ ] Schedule regular backups (optional)

### Verification
- [ ] All services running: `docker-compose ps`
- [ ] Gateway accessible
- [ ] Channels responding
- [ ] Logs show healthy operation
- [ ] Backup exists

### Documentation
- [ ] Read README.md for complete documentation
- [ ] Review QUICKSTART.md for common commands
- [ ] Bookmark maintenance script: `./scripts/06-maintenance.sh`
- [ ] Review troubleshooting section

## Troubleshooting Checklist

If something goes wrong, check:

### Connection Issues
- [ ] Jetson powered on
- [ ] Network connectivity: `ping 192.168.50.69`
- [ ] SSH working: `ssh john@192.168.50.69`
- [ ] Firewall not blocking port 18789

### Docker Issues
- [ ] Docker running: `sudo systemctl status docker`
- [ ] Docker version: `docker --version`
- [ ] User in docker group: `groups`
- [ ] Can run docker: `docker ps`

### Container Issues
- [ ] Container running: `docker-compose ps`
- [ ] Check logs: `docker-compose logs`
- [ ] Environment variables set: `cat .env`
- [ ] API key valid
- [ ] Disk space available: `df -h`

### Gateway Issues
- [ ] Port 18789 open: `netstat -tulpn | grep 18789`
- [ ] Health check: `curl http://localhost:18789/health`
- [ ] Container logs: `docker-compose logs gateway`
- [ ] No binding errors in logs

### Channel Issues
- [ ] Bot tokens correct in .env
- [ ] Channels enabled (TELEGRAM_ENABLED=true)
- [ ] Services restarted after config change
- [ ] Bot has necessary permissions
- [ ] Test with simple message

## Maintenance Schedule

### Daily
- [ ] Check service status: `docker-compose ps`
- [ ] Quick log review: `docker-compose logs --tail=50`

### Weekly
- [ ] Review full logs for errors
- [ ] Check disk space: `df -h`
- [ ] Verify backups exist
- [ ] Test channel connectivity

### Monthly
- [ ] Create backup: `./scripts/06-maintenance.sh` → option 10
- [ ] Clean up old logs: `./scripts/06-maintenance.sh` → option 12
- [ ] Check for updates: `./scripts/06-maintenance.sh` → option 9
- [ ] Review resource usage

## Common Commands Reference

### Status & Monitoring
```bash
# Check deployment status (from local machine)
./deploy.sh --status

# Check service status (on Jetson)
cd ~/openclaw && docker-compose ps

# View logs (on Jetson)
cd ~/openclaw && docker-compose logs -f

# Check resources (on Jetson)
docker stats
```

### Service Management
```bash
# Start services
docker-compose up -d

# Stop services
docker-compose down

# Restart services
docker-compose restart

# Rebuild and restart
docker-compose down && docker-compose build && docker-compose up -d
```

### Maintenance
```bash
# Open maintenance menu
./scripts/06-maintenance.sh

# Configure channels
./scripts/04-configure-channels.sh

# View system info
cat ~/jetson-system-info.txt
```

## Success Criteria

Deployment is successful when:

- [x] All files created locally
- [ ] SSH connection works
- [ ] Docker installed on Jetson
- [ ] OpenClaw container built
- [ ] Container running and healthy
- [ ] Gateway accessible at http://192.168.50.69:18789
- [ ] API key configured
- [ ] At least one channel responding
- [ ] Logs show normal operation
- [ ] Backup created

## Next Steps

After successful deployment:

1. **Test thoroughly** - Send various messages to verify functionality
2. **Configure additional channels** - Add more bots as needed
3. **Set up monitoring** - Configure alerts for issues
4. **Schedule backups** - Automate configuration backups
5. **Optimize performance** - Tune Jetson settings if needed
6. **Secure access** - Configure firewall, change passwords
7. **Document customizations** - Note any changes from defaults

## Quick Reference

| Task | Command |
|------|---------|
| Verify setup | `./scripts/00-verify-setup.sh` |
| Setup SSH | `./scripts/01-ssh-setup.sh` |
| Deploy | `./deploy.sh` |
| Check status | `./deploy.sh --status` |
| View logs | `./deploy.sh --logs` |
| SSH to Jetson | `ssh john@192.168.50.69` |
| Configure channels | `./scripts/04-configure-channels.sh` |
| Maintenance | `./scripts/06-maintenance.sh` |
| Gateway URL | http://192.168.50.69:18789 |

---

**Target System**: NVIDIA Jetson Nano 8GB @ 192.168.50.69
**User**: john
**Directory**: ~/openclaw
**Gateway Port**: 18789
