#!/bin/bash
#
# deploy.sh
# Master deployment script for OpenClaw on Jetson Nano
# This script runs LOCALLY and coordinates remote deployment
#

set -e

# Configuration
JETSON_HOST="192.168.50.69"
JETSON_USER="john"
JETSON_ADDR="${JETSON_USER}@${JETSON_HOST}"
REMOTE_DIR="openclaw"
LOCAL_DIR="$(pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Functions
print_header() {
    echo ""
    echo "=========================================="
    echo "$1"
    echo "=========================================="
    echo ""
}

print_step() {
    echo -e "${BLUE}>>> $1${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

# Check prerequisites
check_prerequisites() {
    print_step "Checking prerequisites..."

    # Check if rsync is available
    if ! command -v rsync &> /dev/null; then
        print_error "rsync is not installed"
        echo "Install with: brew install rsync (macOS) or apt-get install rsync (Linux)"
        exit 1
    fi

    # Check if ssh is available
    if ! command -v ssh &> /dev/null; then
        print_error "ssh is not installed"
        exit 1
    fi

    # Check if we're in the right directory
    if [ ! -d "docker" ] || [ ! -d "scripts" ]; then
        print_error "Must run from ProjectPBot directory"
        echo "Expected structure:"
        echo "  docker/"
        echo "  scripts/"
        exit 1
    fi

    print_success "Prerequisites checked"
}

# Test SSH connection
test_ssh() {
    print_step "Testing SSH connection to ${JETSON_ADDR}..."

    if ssh -o ConnectTimeout=5 -o BatchMode=yes "${JETSON_ADDR}" "echo 'Connected'" &> /dev/null; then
        print_success "SSH connection successful"
        return 0
    else
        print_error "Cannot connect to Jetson Nano"
        echo ""
        echo "Please ensure:"
        echo "  1. Jetson is powered on and connected to network"
        echo "  2. SSH is enabled on the Jetson"
        echo "  3. You have SSH keys set up"
        echo ""
        echo "Run ./scripts/01-ssh-setup.sh to configure SSH access"
        exit 1
    fi
}

# Transfer deployment files
transfer_files() {
    print_step "Transferring deployment files to Jetson..."

    # Create remote directory
    ssh "${JETSON_ADDR}" "mkdir -p ~/${REMOTE_DIR}"

    # Sync docker files
    print_step "  Syncing docker files..."
    rsync -avz --progress \
        docker/ \
        "${JETSON_ADDR}:~/${REMOTE_DIR}/"

    # Sync scripts
    print_step "  Syncing scripts..."
    rsync -avz --progress \
        scripts/ \
        "${JETSON_ADDR}:~/${REMOTE_DIR}/scripts/"

    # Make scripts executable
    ssh "${JETSON_ADDR}" "chmod +x ~/${REMOTE_DIR}/scripts/*.sh"

    print_success "Files transferred successfully"
}

# Install Docker on Jetson
install_docker() {
    print_step "Checking Docker installation on Jetson..."

    if ssh "${JETSON_ADDR}" "command -v docker &> /dev/null"; then
        print_success "Docker already installed"
        return 0
    fi

    print_warning "Docker not installed on Jetson"
    read -p "Install Docker now? (y/n): " install_choice

    if [[ "$install_choice" == "y" || "$install_choice" == "Y" ]]; then
        print_step "Installing Docker on Jetson (this may take 10-15 minutes)..."

        ssh -t "${JETSON_ADDR}" "cd ~/${REMOTE_DIR} && ./scripts/02-docker-install.sh"

        print_success "Docker installation complete"
        print_warning "You may need to log out and back in on the Jetson"
    else
        print_warning "Skipping Docker installation"
        echo "Note: You'll need to install Docker manually before deploying OpenClaw"
    fi
}

# Build OpenClaw
build_openclaw() {
    print_step "Building OpenClaw on Jetson..."

    read -p "Build OpenClaw now? (y/n): " build_choice

    if [[ "$build_choice" == "y" || "$build_choice" == "Y" ]]; then
        print_step "Building (this may take 15-20 minutes on Jetson Nano)..."

        ssh -t "${JETSON_ADDR}" "cd ~/${REMOTE_DIR} && ./scripts/03-openclaw-build.sh"

        print_success "OpenClaw build complete"
    else
        print_warning "Skipping OpenClaw build"
    fi
}

# Configure environment
configure_environment() {
    print_step "Configuring environment..."

    # Check if .env exists on remote
    if ssh "${JETSON_ADDR}" "[ -f ~/${REMOTE_DIR}/.env ]"; then
        print_success ".env file already exists"
        read -p "Edit .env file? (y/n): " edit_choice

        if [[ "$edit_choice" == "y" || "$edit_choice" == "Y" ]]; then
            ssh -t "${JETSON_ADDR}" "cd ~/${REMOTE_DIR} && nano .env"
        fi
    else
        print_warning ".env file not found"
        read -p "Create .env from template? (y/n): " create_choice

        if [[ "$create_choice" == "y" || "$create_choice" == "Y" ]]; then
            ssh "${JETSON_ADDR}" "cd ~/${REMOTE_DIR} && cp .env.example .env"
            print_success ".env file created"
            echo ""
            echo "Please edit the .env file and add your API keys:"
            echo "  ssh ${JETSON_ADDR}"
            echo "  cd ${REMOTE_DIR}"
            echo "  nano .env"
        fi
    fi
}

# Start services
start_services() {
    print_step "Starting OpenClaw services..."

    read -p "Start services now? (y/n): " start_choice

    if [[ "$start_choice" == "y" || "$start_choice" == "Y" ]]; then
        ssh -t "${JETSON_ADDR}" "cd ~/${REMOTE_DIR} && docker-compose up -d"

        print_success "Services started"

        echo ""
        print_step "Waiting for services to be ready..."
        sleep 5

        # Check status
        ssh "${JETSON_ADDR}" "cd ~/${REMOTE_DIR} && docker-compose ps"
    else
        print_warning "Skipping service startup"
    fi
}

# Setup Qwen3 (optional)
setup_qwen3() {
    print_step "Qwen3 Local LLM Setup (Optional)"

    echo ""
    echo "Qwen3 4B provides local, offline LLM inference on your Jetson Nano."
    echo ""
    echo "Features:"
    echo "  • Completely offline operation"
    echo "  • Free after initial setup"
    echo "  • ~2.5GB model download required"
    echo "  • ~20-30 minute one-time build"
    echo "  • 10-15 tokens/sec generation speed"
    echo ""
    echo "Requirements:"
    echo "  • ~5GB disk space (model + Docker image)"
    echo "  • ~3-4GB available RAM when running"
    echo ""

    read -p "Setup Qwen3 4B now? (y/n): " qwen3_choice

    if [[ "$qwen3_choice" == "y" || "$qwen3_choice" == "Y" ]]; then
        print_step "Launching Qwen3 setup script..."
        print_warning "This will open an interactive menu on the Jetson"

        ssh -t "${JETSON_ADDR}" "cd ~/${REMOTE_DIR} && ./scripts/05-qwen3-setup.sh"

        print_success "Qwen3 setup complete"
    else
        print_warning "Skipping Qwen3 setup"
        echo ""
        echo "You can set up Qwen3 later by running:"
        echo "  ssh ${JETSON_ADDR}"
        echo "  cd ${REMOTE_DIR}"
        echo "  ./scripts/05-qwen3-setup.sh"
    fi
}

# Check deployment status
check_status() {
    print_step "Checking deployment status..."

    echo ""
    echo "--- Service Status ---"
    ssh "${JETSON_ADDR}" "cd ~/${REMOTE_DIR} && docker-compose ps"

    echo ""
    echo "--- Gateway URL ---"
    echo "http://${JETSON_HOST}:18789"

    echo ""
    echo "--- Recent Logs ---"
    ssh "${JETSON_ADDR}" "cd ~/${REMOTE_DIR} && docker-compose logs --tail=20"
}

# Show post-deployment instructions
show_instructions() {
    print_header "Deployment Complete!"

    echo "OpenClaw has been deployed to your Jetson Nano"
    echo ""
    echo "Gateway URL: http://${JETSON_HOST}:18789"
    echo ""
    echo "Next steps:"
    echo ""
    echo "1. Configure API keys (if not done already):"
    echo "   ssh ${JETSON_ADDR}"
    echo "   cd ${REMOTE_DIR}"
    echo "   nano .env"
    echo "   docker-compose restart"
    echo ""
    echo "2. Configure channels:"
    echo "   ssh ${JETSON_ADDR}"
    echo "   cd ${REMOTE_DIR}"
    echo "   ./scripts/04-configure-channels.sh"
    echo ""
    echo "3. Monitor the gateway:"
    echo "   ssh ${JETSON_ADDR}"
    echo "   cd ${REMOTE_DIR}"
    echo "   docker-compose logs -f"
    echo ""
    echo "4. Maintenance:"
    echo "   ssh ${JETSON_ADDR}"
    echo "   cd ${REMOTE_DIR}"
    echo "   ./scripts/06-maintenance.sh"
    echo ""
    echo "5. Qwen3 Local LLM (optional):"
    echo "   ssh ${JETSON_ADDR}"
    echo "   cd ${REMOTE_DIR}"
    echo "   ./scripts/05-qwen3-setup.sh"
    echo ""
    echo "Useful commands:"
    echo "  View status:  ssh ${JETSON_ADDR} 'cd ${REMOTE_DIR} && docker-compose ps'"
    echo "  View logs:    ssh ${JETSON_ADDR} 'cd ${REMOTE_DIR} && docker-compose logs -f'"
    echo "  Restart:      ssh ${JETSON_ADDR} 'cd ${REMOTE_DIR} && docker-compose restart'"
    echo "  Stop:         ssh ${JETSON_ADDR} 'cd ${REMOTE_DIR} && docker-compose down'"
    echo ""
}

# Main deployment flow
main() {
    print_header "OpenClaw Deployment to Jetson Nano"

    echo "Target: ${JETSON_ADDR}"
    echo "Remote directory: ~/${REMOTE_DIR}"
    echo ""

    read -p "Proceed with deployment? (y/n): " proceed

    if [[ "$proceed" != "y" && "$proceed" != "Y" ]]; then
        echo "Deployment cancelled"
        exit 0
    fi

    # Run deployment steps
    check_prerequisites
    test_ssh
    transfer_files
    install_docker
    build_openclaw
    configure_environment
    start_services
    setup_qwen3
    check_status
    show_instructions
}

# Handle script arguments
case "${1:-}" in
    --help|-h)
        echo "OpenClaw Deployment Script"
        echo ""
        echo "Usage: ./deploy.sh [OPTIONS]"
        echo ""
        echo "Options:"
        echo "  --help, -h          Show this help message"
        echo "  --transfer-only     Only transfer files, don't deploy"
        echo "  --status            Check deployment status"
        echo "  --logs              View remote logs"
        echo ""
        echo "Configuration:"
        echo "  Target: ${JETSON_ADDR}"
        echo "  Remote directory: ~/${REMOTE_DIR}"
        exit 0
        ;;
    --transfer-only)
        check_prerequisites
        test_ssh
        transfer_files
        print_success "Files transferred. Run ./deploy.sh to complete deployment"
        exit 0
        ;;
    --status)
        check_status
        exit 0
        ;;
    --logs)
        ssh -t "${JETSON_ADDR}" "cd ~/${REMOTE_DIR} && docker-compose logs -f"
        exit 0
        ;;
    "")
        main
        ;;
    *)
        echo "Unknown option: $1"
        echo "Run ./deploy.sh --help for usage information"
        exit 1
        ;;
esac
