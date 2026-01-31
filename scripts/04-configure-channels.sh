#!/bin/bash
#
# 04-configure-channels.sh
# Helper script for configuring OpenClaw channels
# This script runs ON the Jetson Nano
#

set -e

# Configuration
OPENCLAW_DIR="$HOME/openclaw"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo "=========================================="
echo "OpenClaw Channel Configuration"
echo "=========================================="
echo ""

# Check if in OpenClaw directory
if [ ! -d "$OPENCLAW_DIR" ]; then
    echo -e "${RED}Error: OpenClaw directory not found${NC}"
    echo "Expected: $OPENCLAW_DIR"
    echo "Please run ./scripts/03-openclaw-build.sh first"
    exit 1
fi

cd "$OPENCLAW_DIR"

# Check if OpenClaw is running
if ! docker-compose ps | grep -q "Up"; then
    echo -e "${YELLOW}Warning: OpenClaw gateway doesn't appear to be running${NC}"
    read -p "Start the gateway now? (y/n): " start_gateway
    if [[ "$start_gateway" == "y" ]]; then
        docker-compose up -d
        echo "Waiting for gateway to start..."
        sleep 5
    else
        echo "Please start the gateway first: docker-compose up -d"
        exit 1
    fi
fi

# Function to show menu
show_menu() {
    echo ""
    echo "=========================================="
    echo "Channel Configuration Menu"
    echo "=========================================="
    echo ""
    echo "1) Configure Telegram Bot"
    echo "2) Configure Discord Bot"
    echo "3) Configure WhatsApp"
    echo "4) Configure Signal"
    echo "5) List Active Channels"
    echo "6) Test Channel Connection"
    echo "7) Run Onboarding"
    echo "8) View Logs"
    echo "9) Exit"
    echo ""
}

# Function to configure Telegram
configure_telegram() {
    echo ""
    echo -e "${BLUE}=== Telegram Bot Configuration ===${NC}"
    echo ""
    echo "To create a Telegram bot:"
    echo "  1. Open Telegram and search for @BotFather"
    echo "  2. Send /newbot and follow the prompts"
    echo "  3. Copy the bot token provided"
    echo ""
    read -p "Enter your Telegram Bot Token: " bot_token

    if [ -z "$bot_token" ]; then
        echo -e "${RED}Error: Token cannot be empty${NC}"
        return
    fi

    # Update .env file
    if grep -q "TELEGRAM_BOT_TOKEN=" .env; then
        sed -i "s/TELEGRAM_BOT_TOKEN=.*/TELEGRAM_BOT_TOKEN=$bot_token/" .env
        sed -i "s/TELEGRAM_ENABLED=.*/TELEGRAM_ENABLED=true/" .env
    else
        echo "TELEGRAM_BOT_TOKEN=$bot_token" >> .env
        echo "TELEGRAM_ENABLED=true" >> .env
    fi

    echo -e "${GREEN}✓ Telegram bot token saved${NC}"
    echo ""
    echo "Restarting gateway to apply changes..."
    docker-compose restart

    echo ""
    echo -e "${GREEN}Telegram bot configured!${NC}"
    echo "Send a message to your bot to test the connection"
}

# Function to configure Discord
configure_discord() {
    echo ""
    echo -e "${BLUE}=== Discord Bot Configuration ===${NC}"
    echo ""
    echo "To create a Discord bot:"
    echo "  1. Go to https://discord.com/developers/applications"
    echo "  2. Create a New Application"
    echo "  3. Go to Bot section and click Add Bot"
    echo "  4. Copy the bot token"
    echo "  5. Enable MESSAGE CONTENT INTENT"
    echo "  6. Generate OAuth2 URL with bot scope and necessary permissions"
    echo ""
    read -p "Enter your Discord Bot Token: " bot_token

    if [ -z "$bot_token" ]; then
        echo -e "${RED}Error: Token cannot be empty${NC}"
        return
    fi

    # Update .env file
    if grep -q "DISCORD_BOT_TOKEN=" .env; then
        sed -i "s/DISCORD_BOT_TOKEN=.*/DISCORD_BOT_TOKEN=$bot_token/" .env
        sed -i "s/DISCORD_ENABLED=.*/DISCORD_ENABLED=true/" .env
    else
        echo "DISCORD_BOT_TOKEN=$bot_token" >> .env
        echo "DISCORD_ENABLED=true" >> .env
    fi

    echo -e "${GREEN}✓ Discord bot token saved${NC}"
    echo ""
    echo "Restarting gateway to apply changes..."
    docker-compose restart

    echo ""
    echo -e "${GREEN}Discord bot configured!${NC}"
    echo "Invite your bot to a server and send a message to test"
}

# Function to list channels
list_channels() {
    echo ""
    echo -e "${BLUE}=== Active Channels ===${NC}"
    echo ""

    # Use OpenClaw CLI to list channels
    docker-compose exec gateway openclaw channels list || {
        echo "Checking configuration..."
        grep -E "(TELEGRAM_ENABLED|DISCORD_ENABLED)" .env | sed 's/^/  /'
    }
}

# Function to test channel
test_channel() {
    echo ""
    echo -e "${BLUE}=== Test Channel Connection ===${NC}"
    echo ""
    echo "Available channels:"
    echo "  1) Telegram"
    echo "  2) Discord"
    echo ""
    read -p "Select channel to test: " channel_choice

    case $channel_choice in
        1)
            echo "Testing Telegram connection..."
            docker-compose exec gateway openclaw channels test telegram
            ;;
        2)
            echo "Testing Discord connection..."
            docker-compose exec gateway openclaw channels test discord
            ;;
        *)
            echo -e "${RED}Invalid choice${NC}"
            ;;
    esac
}

# Function to run onboarding
run_onboarding() {
    echo ""
    echo -e "${BLUE}=== OpenClaw Onboarding ===${NC}"
    echo ""
    echo "This will guide you through initial setup..."
    echo ""

    docker-compose exec gateway openclaw onboard || {
        echo -e "${YELLOW}Onboarding command not available${NC}"
        echo "Checking configuration manually..."
        echo ""

        # Check API keys
        echo "Checking configuration..."
        if grep -q "ANTHROPIC_API_KEY=.*[a-zA-Z]" .env; then
            echo -e "${GREEN}✓ Anthropic API key configured${NC}"
        else
            echo -e "${YELLOW}⚠ Anthropic API key not set${NC}"
            read -p "Enter your Anthropic API key: " api_key
            if [ ! -z "$api_key" ]; then
                sed -i "s/ANTHROPIC_API_KEY=.*/ANTHROPIC_API_KEY=$api_key/" .env
                echo -e "${GREEN}✓ API key saved${NC}"
            fi
        fi

        # Restart if changes made
        echo ""
        read -p "Restart gateway to apply changes? (y/n): " restart
        if [[ "$restart" == "y" ]]; then
            docker-compose restart
        fi
    }
}

# Function to view logs
view_logs() {
    echo ""
    echo -e "${BLUE}=== OpenClaw Logs ===${NC}"
    echo ""
    echo "Press Ctrl+C to exit logs"
    echo ""
    sleep 2
    docker-compose logs -f --tail=100
}

# Main loop
while true; do
    show_menu
    read -p "Select an option: " choice

    case $choice in
        1)
            configure_telegram
            ;;
        2)
            configure_discord
            ;;
        3)
            echo ""
            echo -e "${YELLOW}WhatsApp configuration requires additional setup${NC}"
            echo "Please refer to OpenClaw documentation for WhatsApp integration"
            ;;
        4)
            echo ""
            echo -e "${YELLOW}Signal configuration requires additional setup${NC}"
            echo "Please refer to OpenClaw documentation for Signal integration"
            ;;
        5)
            list_channels
            ;;
        6)
            test_channel
            ;;
        7)
            run_onboarding
            ;;
        8)
            view_logs
            ;;
        9)
            echo ""
            echo "Exiting..."
            exit 0
            ;;
        *)
            echo -e "${RED}Invalid option${NC}"
            ;;
    esac

    echo ""
    read -p "Press Enter to continue..."
done
