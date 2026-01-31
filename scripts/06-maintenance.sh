#!/bin/bash
#
# 06-maintenance.sh
# Maintenance and troubleshooting utilities for OpenClaw
# This script runs ON the Jetson Nano
#

set -e

# Configuration
OPENCLAW_DIR="$HOME/openclaw"
BACKUP_DIR="$HOME/openclaw-backups"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo "=========================================="
echo "OpenClaw Maintenance & Troubleshooting"
echo "=========================================="
echo ""

# Check if in OpenClaw directory
if [ ! -d "$OPENCLAW_DIR" ]; then
    echo -e "${RED}Error: OpenClaw directory not found${NC}"
    echo "Expected: $OPENCLAW_DIR"
    exit 1
fi

cd "$OPENCLAW_DIR"

# Function to show menu
show_menu() {
    echo ""
    echo "=========================================="
    echo "Maintenance Menu"
    echo "=========================================="
    echo ""
    echo "Status & Monitoring:"
    echo "  1) Check Service Status"
    echo "  2) View Live Logs"
    echo "  3) View Recent Errors"
    echo "  4) System Resource Usage"
    echo ""
    echo "Service Management:"
    echo "  5) Start Services"
    echo "  6) Stop Services"
    echo "  7) Restart Services"
    echo "  8) Rebuild Containers"
    echo ""
    echo "Maintenance:"
    echo "  9) Update OpenClaw"
    echo "  10) Backup Configuration"
    echo "  11) Restore Configuration"
    echo "  12) Clean Up (Remove old logs/images)"
    echo ""
    echo "Troubleshooting:"
    echo "  13) Run Diagnostics"
    echo "  14) Reset to Factory Settings"
    echo "  15) View Docker Info"
    echo ""
    echo "16) Exit"
    echo ""
}

# Function to check status
check_status() {
    echo ""
    echo -e "${BLUE}=== Service Status ===${NC}"
    echo ""

    if docker-compose ps | grep -q "Up"; then
        echo -e "${GREEN}✓ Services are running${NC}"
        echo ""
        docker-compose ps
    else
        echo -e "${RED}✗ Services are not running${NC}"
        echo ""
        docker-compose ps
    fi

    echo ""
    echo "Gateway URL: http://$(hostname -I | awk '{print $1}'):18789"
}

# Function to view logs
view_logs() {
    echo ""
    echo -e "${BLUE}=== Live Logs ===${NC}"
    echo "Press Ctrl+C to exit"
    echo ""
    sleep 2
    docker-compose logs -f --tail=50
}

# Function to view errors
view_errors() {
    echo ""
    echo -e "${BLUE}=== Recent Errors ===${NC}"
    echo ""
    docker-compose logs --tail=200 | grep -i "error\|exception\|failed\|fatal" | tail -50
}

# Function to show resource usage
show_resources() {
    echo ""
    echo -e "${BLUE}=== System Resource Usage ===${NC}"
    echo ""

    echo "--- CPU & Memory ---"
    docker stats --no-stream

    echo ""
    echo "--- Disk Usage ---"
    df -h /

    echo ""
    echo "--- Docker Disk Usage ---"
    docker system df

    echo ""
    echo "--- Jetson Stats (if available) ---"
    if command -v tegrastats &> /dev/null; then
        timeout 3 tegrastats || true
    else
        echo "tegrastats not available"
    fi
}

# Function to start services
start_services() {
    echo ""
    echo -e "${YELLOW}Starting services...${NC}"
    docker-compose up -d
    echo -e "${GREEN}✓ Services started${NC}"
    sleep 3
    docker-compose ps
}

# Function to stop services
stop_services() {
    echo ""
    echo -e "${YELLOW}Stopping services...${NC}"
    docker-compose down
    echo -e "${GREEN}✓ Services stopped${NC}"
}

# Function to restart services
restart_services() {
    echo ""
    echo -e "${YELLOW}Restarting services...${NC}"
    docker-compose restart
    echo -e "${GREEN}✓ Services restarted${NC}"
    sleep 3
    docker-compose ps
}

# Function to rebuild containers
rebuild_containers() {
    echo ""
    echo -e "${YELLOW}Rebuilding containers...${NC}"
    echo "This will rebuild all containers from scratch."
    read -p "Continue? (y/n): " confirm

    if [[ "$confirm" == "y" ]]; then
        docker-compose down
        docker-compose build --no-cache
        docker-compose up -d
        echo -e "${GREEN}✓ Containers rebuilt${NC}"
    else
        echo "Cancelled"
    fi
}

# Function to update OpenClaw
update_openclaw() {
    echo ""
    echo -e "${BLUE}=== Update OpenClaw ===${NC}"
    echo ""

    # Check if git repo
    if [ -d ".git" ]; then
        echo "Pulling latest changes from repository..."
        git fetch origin
        git pull origin main

        echo ""
        echo "Rebuilding containers..."
        docker-compose down
        docker-compose build
        docker-compose up -d

        echo -e "${GREEN}✓ OpenClaw updated${NC}"
    else
        echo -e "${YELLOW}Not a git repository. Pulling latest Docker image...${NC}"
        docker-compose pull
        docker-compose up -d
        echo -e "${GREEN}✓ Updated to latest image${NC}"
    fi
}

# Function to backup configuration
backup_config() {
    echo ""
    echo -e "${BLUE}=== Backup Configuration ===${NC}"
    echo ""

    mkdir -p "$BACKUP_DIR"

    BACKUP_FILE="$BACKUP_DIR/openclaw-backup-$(date +%Y%m%d-%H%M%S).tar.gz"

    echo "Creating backup..."
    tar -czf "$BACKUP_FILE" \
        .env \
        docker-compose.yml \
        data/ \
        2>/dev/null || true

    echo -e "${GREEN}✓ Backup created: $BACKUP_FILE${NC}"
    echo ""
    echo "Backup contents:"
    tar -tzf "$BACKUP_FILE" | head -20
}

# Function to restore configuration
restore_config() {
    echo ""
    echo -e "${BLUE}=== Restore Configuration ===${NC}"
    echo ""

    if [ ! -d "$BACKUP_DIR" ] || [ -z "$(ls -A $BACKUP_DIR)" ]; then
        echo -e "${RED}No backups found in $BACKUP_DIR${NC}"
        return
    fi

    echo "Available backups:"
    ls -lh "$BACKUP_DIR"

    echo ""
    read -p "Enter backup filename to restore: " backup_file

    if [ ! -f "$BACKUP_DIR/$backup_file" ]; then
        echo -e "${RED}Backup file not found${NC}"
        return
    fi

    echo ""
    echo -e "${YELLOW}WARNING: This will overwrite current configuration${NC}"
    read -p "Continue? (y/n): " confirm

    if [[ "$confirm" == "y" ]]; then
        docker-compose down
        tar -xzf "$BACKUP_DIR/$backup_file"
        docker-compose up -d
        echo -e "${GREEN}✓ Configuration restored${NC}"
    else
        echo "Cancelled"
    fi
}

# Function to clean up
cleanup() {
    echo ""
    echo -e "${BLUE}=== Cleanup ===${NC}"
    echo ""

    echo "This will remove:"
    echo "  - Old Docker images"
    echo "  - Stopped containers"
    echo "  - Unused networks"
    echo "  - Build cache"
    echo ""
    read -p "Continue? (y/n): " confirm

    if [[ "$confirm" == "y" ]]; then
        echo "Cleaning up Docker..."
        docker system prune -af --volumes

        echo ""
        echo "Cleaning up logs..."
        find logs/ -type f -name "*.log" -mtime +7 -delete 2>/dev/null || true

        echo -e "${GREEN}✓ Cleanup complete${NC}"

        echo ""
        echo "Current disk usage:"
        docker system df
    else
        echo "Cancelled"
    fi
}

# Function to run diagnostics
run_diagnostics() {
    echo ""
    echo -e "${BLUE}=== System Diagnostics ===${NC}"
    echo ""

    echo "--- Docker Status ---"
    systemctl status docker --no-pager | head -10

    echo ""
    echo "--- Container Status ---"
    docker-compose ps

    echo ""
    echo "--- Recent Container Logs ---"
    docker-compose logs --tail=20

    echo ""
    echo "--- Environment Configuration ---"
    if [ -f .env ]; then
        echo "Required variables:"
        grep -E "(API_KEY|BOT_TOKEN)" .env | sed 's/=.*/=***/' || echo "No API keys configured"
    fi

    echo ""
    echo "--- Network Connectivity ---"
    echo "Testing internet connection..."
    if ping -c 1 8.8.8.8 &> /dev/null; then
        echo -e "${GREEN}✓ Internet connection OK${NC}"
    else
        echo -e "${RED}✗ No internet connection${NC}"
    fi

    echo ""
    echo "--- Disk Space ---"
    df -h / | tail -1

    echo ""
    echo "--- Memory Usage ---"
    free -h

    echo ""
    echo -e "${BLUE}=== Diagnostics Complete ===${NC}"
}

# Function to reset to factory settings
reset_factory() {
    echo ""
    echo -e "${RED}=== RESET TO FACTORY SETTINGS ===${NC}"
    echo ""
    echo -e "${RED}WARNING: This will delete ALL data and configuration!${NC}"
    echo "This includes:"
    echo "  - All containers and images"
    echo "  - Configuration files"
    echo "  - Data directory"
    echo "  - Logs"
    echo ""
    read -p "Type 'RESET' to confirm: " confirm

    if [[ "$confirm" == "RESET" ]]; then
        echo ""
        echo "Creating backup before reset..."
        backup_config

        echo ""
        echo "Stopping and removing containers..."
        docker-compose down -v

        echo "Removing Docker images..."
        docker rmi $(docker images -q openclaw) 2>/dev/null || true

        echo "Removing data..."
        rm -rf data/ logs/

        echo "Removing .env file..."
        rm -f .env

        echo -e "${GREEN}✓ Reset complete${NC}"
        echo ""
        echo "To reinstall, run: ./scripts/03-openclaw-build.sh"
    else
        echo "Cancelled"
    fi
}

# Function to view Docker info
view_docker_info() {
    echo ""
    echo -e "${BLUE}=== Docker Information ===${NC}"
    echo ""
    docker info
}

# Main loop
while true; do
    show_menu
    read -p "Select an option: " choice

    case $choice in
        1) check_status ;;
        2) view_logs ;;
        3) view_errors ;;
        4) show_resources ;;
        5) start_services ;;
        6) stop_services ;;
        7) restart_services ;;
        8) rebuild_containers ;;
        9) update_openclaw ;;
        10) backup_config ;;
        11) restore_config ;;
        12) cleanup ;;
        13) run_diagnostics ;;
        14) reset_factory ;;
        15) view_docker_info ;;
        16)
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
