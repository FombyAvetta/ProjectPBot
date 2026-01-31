#!/bin/bash
#
# docker-entrypoint.sh
# Entrypoint script for OpenClaw container
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "=========================================="
echo "OpenClaw Gateway Starting"
echo "=========================================="

# Check required environment variables
check_env_var() {
    if [ -z "${!1}" ]; then
        echo -e "${RED}Error: $1 is not set${NC}"
        return 1
    else
        echo -e "${GREEN}✓ $1 is configured${NC}"
        return 0
    fi
}

echo ""
echo "Checking configuration..."

# Check LLM provider configuration
case "${LLM_PROVIDER:-anthropic}" in
    anthropic)
        echo "LLM Provider: Anthropic Claude"
        check_env_var ANTHROPIC_API_KEY || {
            echo -e "${YELLOW}Warning: ANTHROPIC_API_KEY not set${NC}"
            echo "The gateway will not be able to process requests"
        }
        ;;
    openai)
        echo "LLM Provider: OpenAI"
        check_env_var OPENAI_API_KEY || {
            echo -e "${YELLOW}Warning: OPENAI_API_KEY not set${NC}"
        }
        ;;
    ollama)
        echo "LLM Provider: Ollama (Local)"
        echo "Ollama host: ${OLLAMA_HOST}"
        ;;
    *)
        echo -e "${RED}Error: Unknown LLM_PROVIDER: ${LLM_PROVIDER}${NC}"
        exit 1
        ;;
esac

# Create data directories if they don't exist
echo ""
echo "Setting up data directories..."
mkdir -p "${DATA_DIR:-/data}" "${LOGS_DIR:-/logs}"
echo -e "${GREEN}✓ Data directories ready${NC}"

# Check channel configuration
echo ""
echo "Channel configuration:"
if [ "${TELEGRAM_ENABLED}" = "true" ]; then
    echo "  - Telegram: Enabled"
    if [ -z "${TELEGRAM_BOT_TOKEN}" ]; then
        echo -e "${YELLOW}    Warning: TELEGRAM_BOT_TOKEN not set${NC}"
    fi
else
    echo "  - Telegram: Disabled"
fi

if [ "${DISCORD_ENABLED}" = "true" ]; then
    echo "  - Discord: Enabled"
    if [ -z "${DISCORD_BOT_TOKEN}" ]; then
        echo -e "${YELLOW}    Warning: DISCORD_BOT_TOKEN not set${NC}"
    fi
else
    echo "  - Discord: Disabled"
fi

# Initialize database if needed
if [ -f "/opt/openclaw/scripts/init_db.py" ]; then
    echo ""
    echo "Initializing database..."
    python3 /opt/openclaw/scripts/init_db.py
fi

echo ""
echo "=========================================="
echo -e "${GREEN}Starting OpenClaw Gateway...${NC}"
echo "=========================================="
echo ""

# Execute the main command
exec "$@"
