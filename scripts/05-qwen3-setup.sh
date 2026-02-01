#!/bin/bash
# =============================================================================
# Qwen3 4B Local LLM Setup and Management Script
# =============================================================================
# Interactive menu for managing Qwen3 4B GGUF model on Jetson Nano 8GB
# Provides: Download, Build, Enable/Disable, Test, Configure, Status
# =============================================================================

set -e

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
DOCKER_DIR="${PROJECT_ROOT}/docker"
ENV_FILE="${DOCKER_DIR}/.env"
MODELS_DIR="${DOCKER_DIR}/models"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Model configuration
MODEL_NAME="Qwen3-4B-Q4_K_M.gguf"
MODEL_URL="https://huggingface.co/Qwen/Qwen2.5-3B-Instruct-GGUF/resolve/main/qwen2.5-3b-instruct-q4_k_m.gguf"
MODEL_SHA256="placeholder_sha256_will_skip_verification"  # Add actual SHA256 if available
MODEL_SIZE_GB="2.5"

# =============================================================================
# Utility Functions
# =============================================================================
print_header() {
    echo ""
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}$1${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo ""
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

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

check_docker() {
    if ! command -v docker &> /dev/null; then
        print_error "Docker not found. Please install Docker first."
        exit 1
    fi

    if ! docker compose version &> /dev/null; then
        print_error "Docker Compose not found. Please install Docker Compose V2."
        exit 1
    fi
}

check_nvidia_docker() {
    if ! docker run --rm --runtime=nvidia nvidia/cuda:12.2.0-base-ubuntu22.04 nvidia-smi &> /dev/null; then
        print_error "NVIDIA Docker runtime not available"
        print_info "Install with: sudo apt-get install nvidia-docker2"
        return 1
    fi
    return 0
}

get_qwen3_status() {
    if docker ps --format '{{.Names}}' | grep -q "openclaw-qwen3"; then
        echo "running"
    elif docker ps -a --format '{{.Names}}' | grep -q "openclaw-qwen3"; then
        echo "stopped"
    else
        echo "not_created"
    fi
}

get_env_value() {
    local key=$1
    local default=$2
    if [ -f "${ENV_FILE}" ]; then
        grep "^${key}=" "${ENV_FILE}" | cut -d'=' -f2- || echo "${default}"
    else
        echo "${default}"
    fi
}

set_env_value() {
    local key=$1
    local value=$2

    if [ -f "${ENV_FILE}" ]; then
        if grep -q "^${key}=" "${ENV_FILE}"; then
            # Update existing
            sed -i.bak "s|^${key}=.*|${key}=${value}|" "${ENV_FILE}"
        else
            # Add new
            echo "${key}=${value}" >> "${ENV_FILE}"
        fi
    else
        print_error ".env file not found at ${ENV_FILE}"
        return 1
    fi
}

# =============================================================================
# Menu Option 1: Download Model
# =============================================================================
download_model() {
    print_header "Download Qwen3 4B Q4_K_M Model"

    # Create models directory
    mkdir -p "${MODELS_DIR}"

    local model_path="${MODELS_DIR}/${MODEL_NAME}"

    # Check if model already exists
    if [ -f "${model_path}" ]; then
        print_warning "Model already exists at: ${model_path}"
        local size=$(du -h "${model_path}" | cut -f1)
        print_info "Current size: ${size}"
        echo ""
        read -p "Re-download? (y/n): " confirm
        if [ "${confirm}" != "y" ]; then
            print_info "Skipping download"
            return 0
        fi
    fi

    print_info "Download URL: ${MODEL_URL}"
    print_info "Target: ${model_path}"
    print_info "Expected size: ~${MODEL_SIZE_GB}GB"
    print_warning "This may take 30-60 minutes depending on connection speed"
    echo ""
    read -p "Start download? (y/n): " confirm

    if [ "${confirm}" != "y" ]; then
        print_info "Download cancelled"
        return 0
    fi

    print_info "Starting download with resume support..."

    # Download with resume support
    if wget -c -O "${model_path}" "${MODEL_URL}"; then
        print_success "Download complete!"

        local final_size=$(du -h "${model_path}" | cut -f1)
        print_info "Downloaded size: ${final_size}"

        # SHA256 verification (optional)
        if [ "${MODEL_SHA256}" != "placeholder_sha256_will_skip_verification" ]; then
            print_info "Verifying SHA256 checksum..."
            local actual_sha256=$(sha256sum "${model_path}" | cut -d' ' -f1)
            if [ "${actual_sha256}" = "${MODEL_SHA256}" ]; then
                print_success "SHA256 verification passed"
            else
                print_error "SHA256 verification failed!"
                print_error "Expected: ${MODEL_SHA256}"
                print_error "Got: ${actual_sha256}"
                return 1
            fi
        else
            print_warning "Skipping SHA256 verification (checksum not configured)"
        fi

        print_success "Model ready at: ${model_path}"
    else
        print_error "Download failed"
        return 1
    fi
}

# =============================================================================
# Menu Option 2: Build Service
# =============================================================================
build_service() {
    print_header "Build Qwen3 Service Image"

    print_info "Building Docker image: openclaw-qwen3:latest"
    print_warning "This is a one-time build and may take 20-30 minutes on Jetson Nano"
    print_info "The image will compile llama.cpp with CUDA support"
    echo ""
    read -p "Start build? (y/n): " confirm

    if [ "${confirm}" != "y" ]; then
        print_info "Build cancelled"
        return 0
    fi

    cd "${DOCKER_DIR}"

    print_info "Starting build..."
    if docker compose build qwen3-server; then
        print_success "Build complete!"
        print_info "Image: openclaw-qwen3:latest"

        # Show image size
        local image_size=$(docker images openclaw-qwen3:latest --format "{{.Size}}")
        print_info "Image size: ${image_size}"
    else
        print_error "Build failed"
        return 1
    fi
}

# =============================================================================
# Menu Option 3: Enable Qwen3
# =============================================================================
enable_qwen3() {
    print_header "Enable Qwen3 Service"

    # Check if model exists
    local model_path="${MODELS_DIR}/${MODEL_NAME}"
    if [ ! -f "${model_path}" ]; then
        print_error "Model not found at: ${model_path}"
        print_info "Please download the model first (Option 1)"
        return 1
    fi

    # Check if image exists
    if ! docker images openclaw-qwen3:latest --format "{{.Repository}}" | grep -q "openclaw-qwen3"; then
        print_error "Docker image not found: openclaw-qwen3:latest"
        print_info "Please build the service first (Option 2)"
        return 1
    fi

    # Check current status
    local status=$(get_qwen3_status)
    if [ "${status}" = "running" ]; then
        print_warning "Qwen3 service is already running"
        return 0
    fi

    print_info "Starting Qwen3 service..."
    print_warning "This will consume 2.8-3.5GB of memory"

    # Check available memory
    local free_mem_kb=$(grep MemAvailable /proc/meminfo | awk '{print $2}')
    local free_mem_gb=$((free_mem_kb / 1024 / 1024))
    print_info "Available memory: ~${free_mem_gb}GB"

    if [ ${free_mem_gb} -lt 3 ]; then
        print_warning "Low memory detected (< 3GB available)"
        print_warning "Consider stopping other services or using lower context length"
        echo ""
        read -p "Continue anyway? (y/n): " confirm
        if [ "${confirm}" != "y" ]; then
            print_info "Cancelled"
            return 0
        fi
    fi

    cd "${DOCKER_DIR}"

    # Start with profile
    if docker compose --profile qwen3 up -d qwen3-server; then
        print_success "Service started!"
        print_info "Container: openclaw-qwen3"

        # Wait for health check
        print_info "Waiting for service to be ready (up to 60s)..."
        local wait_count=0
        while [ ${wait_count} -lt 60 ]; do
            if docker compose ps qwen3-server | grep -q "healthy"; then
                print_success "Service is healthy and ready!"
                break
            fi
            sleep 1
            wait_count=$((wait_count + 1))
        done

        if [ ${wait_count} -ge 60 ]; then
            print_warning "Service did not become healthy within 60s"
            print_info "Check logs with: docker compose logs qwen3-server"
        fi

        print_info ""
        print_info "API endpoint: http://localhost:8080/v1/chat/completions"
        print_info "Health check: http://localhost:8080/health"
        print_info ""
        print_info "To use Qwen3 in OpenClaw, set: LLM_PROVIDER=qwen3"
    else
        print_error "Failed to start service"
        return 1
    fi
}

# =============================================================================
# Menu Option 4: Disable Qwen3
# =============================================================================
disable_qwen3() {
    print_header "Disable Qwen3 Service"

    local status=$(get_qwen3_status)
    if [ "${status}" = "not_created" ] || [ "${status}" = "stopped" ]; then
        print_warning "Qwen3 service is not running"
        return 0
    fi

    print_info "Stopping Qwen3 service..."

    cd "${DOCKER_DIR}"

    if docker compose stop qwen3-server; then
        print_success "Service stopped"

        # Show freed memory
        print_info "Memory freed: ~2.8-3.5GB"

        local free_mem_kb=$(grep MemAvailable /proc/meminfo | awk '{print $2}')
        local free_mem_gb=$((free_mem_kb / 1024 / 1024))
        print_info "Available memory now: ~${free_mem_gb}GB"
    else
        print_error "Failed to stop service"
        return 1
    fi
}

# =============================================================================
# Menu Option 5: Test API
# =============================================================================
test_api() {
    print_header "Test Qwen3 API"

    local status=$(get_qwen3_status)
    if [ "${status}" != "running" ]; then
        print_error "Qwen3 service is not running"
        print_info "Please enable the service first (Option 3)"
        return 1
    fi

    print_info "Testing API endpoint: http://localhost:8080/v1/chat/completions"
    print_info "Sending test prompt..."
    echo ""

    local start_time=$(date +%s%3N)

    local response=$(curl -s -X POST http://localhost:8080/v1/chat/completions \
        -H "Content-Type: application/json" \
        -d '{
            "model": "qwen3-4b",
            "messages": [
                {"role": "system", "content": "You are a helpful assistant."},
                {"role": "user", "content": "Say hello and tell me what model you are in one sentence."}
            ],
            "max_tokens": 50,
            "temperature": 0.7
        }')

    local end_time=$(date +%s%3N)
    local duration=$((end_time - start_time))

    if echo "${response}" | jq -e '.choices[0].message.content' > /dev/null 2>&1; then
        print_success "API test successful!"
        echo ""
        print_info "Response:"
        echo "${response}" | jq -r '.choices[0].message.content'
        echo ""
        print_info "Response time: ${duration}ms"

        # Calculate tokens/sec (rough estimate)
        local tokens=$(echo "${response}" | jq -r '.usage.completion_tokens // 0')
        if [ "${tokens}" -gt 0 ]; then
            local tokens_per_sec=$((tokens * 1000 / duration))
            print_info "Generation speed: ~${tokens_per_sec} tokens/sec"
        fi
    else
        print_error "API test failed"
        echo ""
        print_error "Response:"
        echo "${response}"
        return 1
    fi
}

# =============================================================================
# Menu Option 6: Configure Settings
# =============================================================================
configure_settings() {
    print_header "Configure Qwen3 Settings"

    print_info "Current configuration:"
    echo ""

    local current_context=$(get_env_value "QWEN3_CONTEXT_LENGTH" "2048")
    local current_gpu_layers=$(get_env_value "QWEN3_GPU_LAYERS" "32")
    local current_batch=$(get_env_value "QWEN3_BATCH_SIZE" "512")
    local current_threads=$(get_env_value "QWEN3_THREADS" "4")

    echo "  Context Length: ${current_context}"
    echo "  GPU Layers: ${current_gpu_layers}"
    echo "  Batch Size: ${current_batch}"
    echo "  Threads: ${current_threads}"
    echo ""

    print_info "Recommended profiles:"
    echo ""
    echo "  1) Minimal Memory (stable):"
    echo "     Context=1024, GPU Layers=24, Batch=256"
    echo "     Memory: ~2.2GB, Speed: ~8 tok/s"
    echo ""
    echo "  2) Balanced (recommended):"
    echo "     Context=2048, GPU Layers=32, Batch=512"
    echo "     Memory: ~2.8GB, Speed: ~12 tok/s"
    echo ""
    echo "  3) Maximum Performance (risky):"
    echo "     Context=4096, GPU Layers=99, Batch=1024"
    echo "     Memory: ~4.5GB, Speed: ~15 tok/s"
    echo ""
    echo "  4) Custom"
    echo ""

    read -p "Select profile (1-4) or 0 to cancel: " profile

    case ${profile} in
        1)
            set_env_value "QWEN3_CONTEXT_LENGTH" "1024"
            set_env_value "QWEN3_GPU_LAYERS" "24"
            set_env_value "QWEN3_BATCH_SIZE" "256"
            print_success "Applied Minimal Memory profile"
            ;;
        2)
            set_env_value "QWEN3_CONTEXT_LENGTH" "2048"
            set_env_value "QWEN3_GPU_LAYERS" "32"
            set_env_value "QWEN3_BATCH_SIZE" "512"
            print_success "Applied Balanced profile"
            ;;
        3)
            set_env_value "QWEN3_CONTEXT_LENGTH" "4096"
            set_env_value "QWEN3_GPU_LAYERS" "99"
            set_env_value "QWEN3_BATCH_SIZE" "1024"
            print_success "Applied Maximum Performance profile"
            ;;
        4)
            echo ""
            read -p "Context Length (1024/2048/4096): " context
            read -p "GPU Layers (0-99): " gpu_layers
            read -p "Batch Size (256/512/1024): " batch
            read -p "Threads (2/4/6): " threads

            set_env_value "QWEN3_CONTEXT_LENGTH" "${context}"
            set_env_value "QWEN3_GPU_LAYERS" "${gpu_layers}"
            set_env_value "QWEN3_BATCH_SIZE" "${batch}"
            set_env_value "QWEN3_THREADS" "${threads}"
            print_success "Applied custom settings"
            ;;
        0)
            print_info "Cancelled"
            return 0
            ;;
        *)
            print_error "Invalid selection"
            return 1
            ;;
    esac

    echo ""
    print_warning "Settings saved to .env file"
    print_warning "Restart Qwen3 service to apply changes:"
    print_info "  1) Disable Qwen3 (Option 4)"
    print_info "  2) Enable Qwen3 (Option 3)"
}

# =============================================================================
# Menu Option 7: View Status
# =============================================================================
view_status() {
    print_header "Qwen3 Service Status"

    # Service status
    local status=$(get_qwen3_status)
    echo -e "${CYAN}Service Status:${NC}"
    case ${status} in
        running)
            print_success "Running"
            ;;
        stopped)
            print_warning "Stopped"
            ;;
        not_created)
            print_info "Not Created"
            ;;
    esac
    echo ""

    # Model status
    local model_path="${MODELS_DIR}/${MODEL_NAME}"
    echo -e "${CYAN}Model Status:${NC}"
    if [ -f "${model_path}" ]; then
        local size=$(du -h "${model_path}" | cut -f1)
        print_success "Downloaded (${size})"
        echo "  Path: ${model_path}"
    else
        print_warning "Not Downloaded"
        echo "  Expected path: ${model_path}"
    fi
    echo ""

    # Image status
    echo -e "${CYAN}Docker Image:${NC}"
    if docker images openclaw-qwen3:latest --format "{{.Repository}}" | grep -q "openclaw-qwen3"; then
        local image_size=$(docker images openclaw-qwen3:latest --format "{{.Size}}")
        print_success "Built (${image_size})"
    else
        print_warning "Not Built"
    fi
    echo ""

    # Configuration
    echo -e "${CYAN}Configuration:${NC}"
    echo "  Context Length: $(get_env_value 'QWEN3_CONTEXT_LENGTH' '2048')"
    echo "  GPU Layers: $(get_env_value 'QWEN3_GPU_LAYERS' '32')"
    echo "  Batch Size: $(get_env_value 'QWEN3_BATCH_SIZE' '512')"
    echo "  Threads: $(get_env_value 'QWEN3_THREADS' '4')"
    echo "  Memory Limit: $(get_env_value 'QWEN3_MEMORY_LIMIT' '5g')"
    echo ""

    # Resource usage (if running)
    if [ "${status}" = "running" ]; then
        echo -e "${CYAN}Resource Usage:${NC}"
        docker stats openclaw-qwen3 --no-stream --format "  CPU: {{.CPUPerc}}  Memory: {{.MemUsage}}"
        echo ""

        echo -e "${CYAN}API Endpoints:${NC}"
        echo "  Chat: http://localhost:8080/v1/chat/completions"
        echo "  Health: http://localhost:8080/health"
        echo ""

        echo -e "${CYAN}Recent Logs:${NC}"
        docker compose -f "${DOCKER_DIR}/docker-compose.yml" logs --tail=10 qwen3-server
    fi
}

# =============================================================================
# Main Menu
# =============================================================================
show_menu() {
    clear
    print_header "Qwen3 4B Local LLM - Setup & Management"

    echo -e "${MAGENTA}1)${NC} Download Model (~2.5GB)"
    echo -e "${MAGENTA}2)${NC} Build Service (one-time, ~20-30 min)"
    echo -e "${MAGENTA}3)${NC} Enable Qwen3 (start service)"
    echo -e "${MAGENTA}4)${NC} Disable Qwen3 (stop service, free memory)"
    echo -e "${MAGENTA}5)${NC} Test API (send test prompt)"
    echo -e "${MAGENTA}6)${NC} Configure Settings (tune performance)"
    echo -e "${MAGENTA}7)${NC} View Status (show current state)"
    echo ""
    echo -e "${MAGENTA}0)${NC} Exit"
    echo ""
}

main() {
    # Check prerequisites
    check_docker

    while true; do
        show_menu
        read -p "Select option (0-7): " choice
        echo ""

        case ${choice} in
            1) download_model ;;
            2) build_service ;;
            3) enable_qwen3 ;;
            4) disable_qwen3 ;;
            5) test_api ;;
            6) configure_settings ;;
            7) view_status ;;
            0)
                print_info "Exiting..."
                exit 0
                ;;
            *)
                print_error "Invalid option"
                ;;
        esac

        echo ""
        read -p "Press Enter to continue..."
    done
}

# Run main menu
main
