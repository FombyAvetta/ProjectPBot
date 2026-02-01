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
    echo "Qwen3 Local LLM:"
    echo "  17) Enable Qwen3 Service"
    echo "  18) Disable Qwen3 Service"
    echo "  19) Qwen3 Status & Diagnostics"
    echo "  20) Qwen3 Performance Test"
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

# Function to enable Qwen3
enable_qwen3() {
    echo ""
    echo -e "${BLUE}=== Enable Qwen3 Service ===${NC}"
    echo ""

    # Check if setup script exists
    if [ ! -f "$OPENCLAW_DIR/scripts/05-qwen3-setup.sh" ]; then
        echo -e "${RED}Qwen3 setup script not found${NC}"
        echo "Expected: $OPENCLAW_DIR/scripts/05-qwen3-setup.sh"
        return
    fi

    # Check if model exists
    if [ ! -f "$OPENCLAW_DIR/models/Qwen3-4B-Q4_K_M.gguf" ]; then
        echo -e "${YELLOW}Model not found. Please run Qwen3 setup first:${NC}"
        echo "$OPENCLAW_DIR/scripts/05-qwen3-setup.sh"
        return
    fi

    # Check available memory
    free_mem_kb=$(grep MemAvailable /proc/meminfo | awk '{print $2}')
    free_mem_gb=$((free_mem_kb / 1024 / 1024))
    echo "Available memory: ~${free_mem_gb}GB"

    if [ ${free_mem_gb} -lt 3 ]; then
        echo -e "${YELLOW}WARNING: Low memory (< 3GB available)${NC}"
        echo "Qwen3 requires ~2.8-3.5GB. Consider stopping other services."
        read -p "Continue? (y/n): " confirm
        if [[ "$confirm" != "y" ]]; then
            echo "Cancelled"
            return
        fi
    fi

    echo "Starting Qwen3 service..."
    cd "$OPENCLAW_DIR"
    docker-compose --profile qwen3 up -d qwen3-server

    echo ""
    echo -e "${GREEN}✓ Qwen3 service enabled${NC}"
    echo "API: http://localhost:8080/v1/chat/completions"
    echo "Set LLM_PROVIDER=qwen3 to use it in OpenClaw"
}

# Function to disable Qwen3
disable_qwen3() {
    echo ""
    echo -e "${BLUE}=== Disable Qwen3 Service ===${NC}"
    echo ""

    if ! docker ps --format '{{.Names}}' | grep -q "openclaw-qwen3"; then
        echo -e "${YELLOW}Qwen3 service is not running${NC}"
        return
    fi

    echo "Stopping Qwen3 service..."
    cd "$OPENCLAW_DIR"
    docker-compose stop qwen3-server

    echo ""
    echo -e "${GREEN}✓ Qwen3 service disabled${NC}"
    echo "Memory freed: ~2.8-3.5GB"

    free_mem_kb=$(grep MemAvailable /proc/meminfo | awk '{print $2}')
    free_mem_gb=$((free_mem_kb / 1024 / 1024))
    echo "Available memory now: ~${free_mem_gb}GB"
}

# Function to show Qwen3 status and diagnostics
qwen3_status() {
    echo ""
    echo -e "${BLUE}=== Qwen3 Status & Diagnostics ===${NC}"
    echo ""

    # Service status
    echo "--- Service Status ---"
    if docker ps --format '{{.Names}}' | grep -q "openclaw-qwen3"; then
        echo -e "${GREEN}✓ Running${NC}"
        echo ""
        docker ps --filter "name=openclaw-qwen3" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    else
        echo -e "${YELLOW}Not Running${NC}"
    fi

    echo ""
    echo "--- Model Status ---"
    if [ -f "$OPENCLAW_DIR/models/Qwen3-4B-Q4_K_M.gguf" ]; then
        model_size=$(du -h "$OPENCLAW_DIR/models/Qwen3-4B-Q4_K_M.gguf" | cut -f1)
        echo -e "${GREEN}✓ Downloaded (${model_size})${NC}"
    else
        echo -e "${YELLOW}Not Downloaded${NC}"
    fi

    echo ""
    echo "--- Docker Image ---"
    if docker images openclaw-qwen3:latest --format "{{.Repository}}" | grep -q "openclaw-qwen3"; then
        image_size=$(docker images openclaw-qwen3:latest --format "{{.Size}}")
        echo -e "${GREEN}✓ Built (${image_size})${NC}"
    else
        echo -e "${YELLOW}Not Built${NC}"
    fi

    # Resource usage if running
    if docker ps --format '{{.Names}}' | grep -q "openclaw-qwen3"; then
        echo ""
        echo "--- Resource Usage ---"
        docker stats openclaw-qwen3 --no-stream --format "CPU: {{.CPUPerc}}  Memory: {{.MemUsage}}"

        echo ""
        echo "--- Health Check ---"
        health=$(docker inspect --format='{{.State.Health.Status}}' openclaw-qwen3 2>/dev/null || echo "unknown")
        if [ "$health" = "healthy" ]; then
            echo -e "${GREEN}✓ Healthy${NC}"
        else
            echo -e "${YELLOW}Status: ${health}${NC}"
        fi

        echo ""
        echo "--- API Test ---"
        if curl -s http://localhost:8080/health > /dev/null 2>&1; then
            echo -e "${GREEN}✓ API responding${NC}"
        else
            echo -e "${RED}✗ API not responding${NC}"
        fi

        echo ""
        echo "--- Recent Logs (last 15 lines) ---"
        docker logs openclaw-qwen3 --tail=15
    fi

    echo ""
    echo "--- Configuration ---"
    if [ -f "$OPENCLAW_DIR/.env" ]; then
        echo "Context Length: $(grep QWEN3_CONTEXT_LENGTH $OPENCLAW_DIR/.env | cut -d'=' -f2 || echo '2048')"
        echo "GPU Layers: $(grep QWEN3_GPU_LAYERS $OPENCLAW_DIR/.env | cut -d'=' -f2 || echo '32')"
        echo "Batch Size: $(grep QWEN3_BATCH_SIZE $OPENCLAW_DIR/.env | cut -d'=' -f2 || echo '512')"
    fi

    echo ""
    echo "--- Memory Warning ---"
    free_mem_kb=$(grep MemAvailable /proc/meminfo | awk '{print $2}')
    free_mem_gb=$((free_mem_kb / 1024 / 1024))
    used_mem_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    used_mem_kb=$((used_mem_kb - free_mem_kb))
    used_mem_gb=$((used_mem_kb / 1024 / 1024))
    total_mem_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    total_mem_gb=$((total_mem_kb / 1024 / 1024))
    usage_pct=$((used_mem_gb * 100 / total_mem_gb))

    echo "Total Memory: ${total_mem_gb}GB"
    echo "Used Memory: ${used_mem_gb}GB"
    echo "Available: ${free_mem_gb}GB"
    echo "Usage: ${usage_pct}%"

    if [ ${usage_pct} -gt 90 ]; then
        echo -e "${RED}⚠ WARNING: Memory usage > 90%!${NC}"
        echo "Consider disabling Qwen3 or other services"
    elif [ ${usage_pct} -gt 80 ]; then
        echo -e "${YELLOW}⚠ Caution: Memory usage > 80%${NC}"
    fi
}

# Function to run Qwen3 performance test
qwen3_performance_test() {
    echo ""
    echo -e "${BLUE}=== Qwen3 Performance Test ===${NC}"
    echo ""

    if ! docker ps --format '{{.Names}}' | grep -q "openclaw-qwen3"; then
        echo -e "${RED}Qwen3 service is not running${NC}"
        echo "Enable it first (Option 17)"
        return
    fi

    echo "Running performance test..."
    echo ""

    # Test 1: Simple prompt
    echo "Test 1: Simple prompt (50 tokens)"
    start_time=$(date +%s%3N)
    response=$(curl -s -X POST http://localhost:8080/v1/chat/completions \
        -H "Content-Type: application/json" \
        -d '{
            "model": "qwen3-4b",
            "messages": [{"role": "user", "content": "Count from 1 to 10"}],
            "max_tokens": 50,
            "temperature": 0.7
        }')
    end_time=$(date +%s%3N)

    if echo "$response" | jq -e '.choices[0].message.content' > /dev/null 2>&1; then
        duration=$((end_time - start_time))
        tokens=$(echo "$response" | jq -r '.usage.completion_tokens // 0')
        if [ "$tokens" -gt 0 ]; then
            tokens_per_sec=$((tokens * 1000 / duration))
            echo -e "${GREEN}✓ Success${NC}"
            echo "  Time: ${duration}ms"
            echo "  Tokens: ${tokens}"
            echo "  Speed: ${tokens_per_sec} tok/s"
        else
            echo -e "${YELLOW}⚠ No tokens generated${NC}"
        fi
    else
        echo -e "${RED}✗ Failed${NC}"
    fi

    echo ""

    # Test 2: Health check latency
    echo "Test 2: API Health Check Latency"
    health_time=$(curl -o /dev/null -s -w '%{time_total}' http://localhost:8080/health)
    health_time_ms=$(echo "$health_time * 1000" | bc)
    echo "  Latency: ${health_time_ms}ms"

    echo ""
    echo "--- Performance Summary ---"
    echo "Expected on Jetson Nano 8GB:"
    echo "  Speed: 10-15 tok/s (GPU), 2-3 tok/s (CPU)"
    echo "  Latency: < 500ms first token"
    echo ""
    echo "For detailed benchmarking, use:"
    echo "  $OPENCLAW_DIR/scripts/07-benchmark-qwen3.sh"
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
        17) enable_qwen3 ;;
        18) disable_qwen3 ;;
        19) qwen3_status ;;
        20) qwen3_performance_test ;;
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
