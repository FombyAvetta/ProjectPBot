# Configure OpenClaw Channels and Onboarding

## Objective
Complete the OpenClaw onboarding process and configure messaging channels.

## Target Device
- Host: 192.168.50.69
- User: john
- OpenClaw running in Docker

## Prerequisites
- OpenClaw container built and running (see 03-openclaw-docker-build.md)
- API key configured in .env file

## Tasks

### 1. Run Interactive Onboarding
The onboarding wizard will configure:
- Model provider (Anthropic, OpenAI, etc.)
- Gateway settings
- Initial channels

```bash
# Run onboarding interactively (requires -t for TTY)
ssh -t john@192.168.50.69 "cd ~/openclaw && docker compose run --rm openclaw-cli onboard"
```

During onboarding, select:
- **Gateway bind**: `lan` (to access from other devices)
- **Gateway auth**: `token`
- **Gateway token**: Use the one from your .env file
- **Model provider**: Your choice (Anthropic recommended)

### 2. Configure Telegram Channel
Create a Telegram bot first:
1. Message @BotFather on Telegram
2. Send `/newbot`
3. Follow prompts to create bot
4. Copy the bot token

Then add to OpenClaw:
```bash
ssh john@192.168.50.69 << 'EOF'
cd ~/openclaw
# Replace YOUR_TELEGRAM_BOT_TOKEN with your actual token
docker compose run --rm openclaw-cli channels add --channel telegram --token "YOUR_TELEGRAM_BOT_TOKEN"
EOF
```

### 3. Configure Discord Channel
Create a Discord bot first:
1. Go to https://discord.com/developers/applications
2. Create New Application
3. Go to Bot section, create bot
4. Copy the bot token
5. Enable "Message Content Intent" in Bot settings
6. Generate invite URL with bot permissions

Then add to OpenClaw:
```bash
ssh john@192.168.50.69 << 'EOF'
cd ~/openclaw
docker compose run --rm openclaw-cli channels add --channel discord --token "YOUR_DISCORD_BOT_TOKEN"
EOF
```

### 4. Configure WhatsApp Channel (via QR Code)
WhatsApp requires scanning a QR code:

```bash
# This will display a QR code - scan with WhatsApp
ssh -t john@192.168.50.69 "cd ~/openclaw && docker compose run --rm openclaw-cli channels login"
```

### 5. Configure Signal Channel
Signal requires linking as a secondary device:

```bash
ssh -t john@192.168.50.69 "cd ~/openclaw && docker compose run --rm openclaw-cli channels add --channel signal"
```

### 6. List Configured Channels
```bash
ssh john@192.168.50.69 "cd ~/openclaw && docker compose run --rm openclaw-cli channels list"
```

### 7. Test Channel Connection
```bash
# Send a test message (replace with your phone number for WhatsApp/Signal)
ssh john@192.168.50.69 << 'EOF'
cd ~/openclaw
docker compose run --rm openclaw-cli message send --to "+1234567890" --message "Hello from OpenClaw on Jetson!"
EOF
```

### 8. Restart Gateway After Channel Changes
```bash
ssh john@192.168.50.69 "cd ~/openclaw && docker compose restart openclaw-gateway"
```

## Channel Configuration Reference

### Telegram Setup
```bash
# Add bot
docker compose run --rm openclaw-cli channels add --channel telegram --token "<BOT_TOKEN>"

# Remove channel
docker compose run --rm openclaw-cli channels remove --channel telegram
```

### Discord Setup
```bash
# Add bot
docker compose run --rm openclaw-cli channels add --channel discord --token "<BOT_TOKEN>"

# Required bot permissions:
# - Send Messages
# - Read Message History
# - Add Reactions
# - Attach Files
```

### Slack Setup
```bash
# Requires Slack App with Socket Mode
docker compose run --rm openclaw-cli channels add --channel slack \
    --app-token "xapp-..." \
    --bot-token "xoxb-..."
```

## DM Pairing (Security)
Enable DM pairing to prevent unauthorized access:

```bash
ssh john@192.168.50.69 << 'EOF'
cd ~/openclaw

# View pairing requests
docker compose run --rm openclaw-cli pairing list

# Approve a pairing code
docker compose run --rm openclaw-cli pairing approve telegram <CODE>
EOF
```

## Verify Setup
```bash
ssh john@192.168.50.69 << 'EOF'
cd ~/openclaw
echo "=== Gateway Status ==="
docker compose run --rm openclaw-cli status

echo ""
echo "=== Configured Channels ==="
docker compose run --rm openclaw-cli channels list

echo ""
echo "=== Gateway Health ==="
curl -s http://localhost:18789/health | head -20
EOF
```

## Troubleshooting

### Channel won't connect
```bash
# Check logs for errors
ssh john@192.168.50.69 "docker logs openclaw 2>&1 | grep -i error | tail -20"

# Restart gateway
ssh john@192.168.50.69 "cd ~/openclaw && docker compose restart openclaw-gateway"
```

### Re-authenticate WhatsApp
```bash
ssh -t john@192.168.50.69 "cd ~/openclaw && docker compose run --rm openclaw-cli channels login --channel whatsapp"
```

### Check channel status
```bash
ssh john@192.168.50.69 "cd ~/openclaw && docker compose run --rm openclaw-cli channels status"
```

## Expected Outcomes
- Onboarding completed with model provider configured
- At least one messaging channel connected
- DM pairing enabled for security
- Gateway accessible via configured channels
