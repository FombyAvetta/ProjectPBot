#!/bin/bash
# =============================================================================
# Qwen3 4B GGUF Server Entrypoint Script
# =============================================================================
# Auto-tuning startup script for llama-server with CUDA acceleration
# Validates environment, checks GPU availability, and tunes parameters
# based on available memory for optimal performance on Jetson Nano 8GB
# =============================================================================

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# =============================================================================
# Signal handling for graceful shutdown
# =============================================================================
LLAMA_PID=""

cleanup() {
    log_info "Received shutdown signal, stopping llama-server gracefully..."
    if [ -n "$LLAMA_PID" ]; then
        kill -TERM "$LLAMA_PID" 2>/dev/null || true
        wait "$LLAMA_PID" 2>/dev/null || true
    fi
    log_success "Shutdown complete"
    exit 0
}

trap cleanup SIGTERM SIGINT SIGQUIT

# =============================================================================
# Environment validation
# =============================================================================
log_info "Starting Qwen3 4B GGUF Server initialization..."
log_info "Model path: ${MODEL_PATH}"
log_info "Context length: ${CONTEXT_LENGTH}"
log_info "Batch size: ${BATCH_SIZE}"
log_info "Threads: ${THREADS}"
log_info "Parallel requests: ${PARALLEL_REQUESTS}"

# Validate model file exists
if [ ! -f "${MODEL_PATH}" ]; then
    log_error "Model file not found at ${MODEL_PATH}"
    log_error "Please download the model using: ./scripts/05-qwen3-setup.sh"
    exit 1
fi

log_success "Model file found: ${MODEL_PATH}"
MODEL_SIZE=$(du -h "${MODEL_PATH}" | cut -f1)
log_info "Model size: ${MODEL_SIZE}"

# =============================================================================
# GPU availability and memory detection
# =============================================================================
log_info "Checking GPU availability..."

GPU_AVAILABLE=false
GPU_MEMORY_GB=0

if command -v nvidia-smi &> /dev/null; then
    if nvidia-smi &> /dev/null; then
        GPU_AVAILABLE=true
        # Extract GPU memory in GB (handle Jetson-specific format)
        GPU_MEMORY_MB=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits 2>/dev/null | head -n 1 || echo "0")
        if [ -z "$GPU_MEMORY_MB" ] || [ "$GPU_MEMORY_MB" = "0" ]; then
            # Fallback: Try tegrastats for Jetson devices
            GPU_MEMORY_MB=7400  # Jetson Nano 8GB typical shared memory
            log_warning "Could not query GPU memory via nvidia-smi, assuming 7.4GB for Jetson Nano"
        fi
        GPU_MEMORY_GB=$((GPU_MEMORY_MB / 1024))
        log_success "GPU detected: NVIDIA GPU with ~${GPU_MEMORY_GB}GB memory"
    else
        log_warning "nvidia-smi found but failed to query GPU"
    fi
else
    log_warning "nvidia-smi not found"
fi

if [ "$GPU_AVAILABLE" = false ]; then
    log_warning "No GPU available, falling back to CPU-only mode"
    log_warning "Performance will be significantly reduced (~2-3 tokens/sec)"
fi

# =============================================================================
# Auto-tune GPU layers based on available memory
# =============================================================================
OPTIMAL_GPU_LAYERS=${GPU_LAYERS}

if [ "$GPU_AVAILABLE" = true ]; then
    log_info "Auto-tuning GPU layer offloading based on available memory..."

    # Auto-tune logic:
    # - GPU memory > 4GB: Full offload (99 layers) - Best performance
    # - GPU memory 3-4GB: Partial offload (32 layers) - Balanced
    # - GPU memory < 3GB: CPU only (0 layers) - Safe mode
    # - If GPU_LAYERS is already set via env var, respect it

    if [ "${GPU_LAYERS}" = "auto" ] || [ -z "${GPU_LAYERS}" ] || [ "${GPU_LAYERS}" = "32" ]; then
        if [ ${GPU_MEMORY_GB} -gt 4 ]; then
            OPTIMAL_GPU_LAYERS=99
            log_info "High memory detected (${GPU_MEMORY_GB}GB) -> Full GPU offload (99 layers)"
        elif [ ${GPU_MEMORY_GB} -ge 3 ]; then
            OPTIMAL_GPU_LAYERS=32
            log_info "Medium memory detected (${GPU_MEMORY_GB}GB) -> Partial GPU offload (32 layers)"
        else
            OPTIMAL_GPU_LAYERS=0
            log_warning "Low memory detected (${GPU_MEMORY_GB}GB) -> CPU-only mode (0 layers)"
        fi
    else
        OPTIMAL_GPU_LAYERS=${GPU_LAYERS}
        log_info "Using manually configured GPU layers: ${OPTIMAL_GPU_LAYERS}"
    fi
else
    OPTIMAL_GPU_LAYERS=0
    log_info "CPU-only mode: 0 GPU layers"
fi

# =============================================================================
# Build llama-server command
# =============================================================================
log_info "Building llama-server command with optimized parameters..."

LLAMA_CMD=(
    "/app/llama-server"
    "--model" "${MODEL_PATH}"
    "--host" "${HOST}"
    "--port" "${PORT}"
    "--ctx-size" "${CONTEXT_LENGTH}"
    "--batch-size" "${BATCH_SIZE}"
    "--threads" "${THREADS}"
    "--n-gpu-layers" "${OPTIMAL_GPU_LAYERS}"
    "--parallel" "${PARALLEL_REQUESTS}"
    "--timeout" "${TIMEOUT}"
    "--chat-template" "qwen3"
    "--log-disable"
    "--no-mmap"
)

# Add GPU-specific optimizations if available
if [ "$GPU_AVAILABLE" = true ] && [ ${OPTIMAL_GPU_LAYERS} -gt 0 ]; then
    LLAMA_CMD+=("--flash-attn")
fi

# Log final configuration
log_info "==================================================================="
log_info "Final Configuration:"
log_info "  Host: ${HOST}:${PORT}"
log_info "  Model: $(basename ${MODEL_PATH})"
log_info "  Context Length: ${CONTEXT_LENGTH} tokens"
log_info "  Batch Size: ${BATCH_SIZE}"
log_info "  Threads: ${THREADS}"
log_info "  GPU Layers: ${OPTIMAL_GPU_LAYERS}"
log_info "  Parallel Requests: ${PARALLEL_REQUESTS}"
log_info "  GPU Available: ${GPU_AVAILABLE}"
if [ "$GPU_AVAILABLE" = true ]; then
    log_info "  GPU Memory: ~${GPU_MEMORY_GB}GB"
fi
log_info "==================================================================="

# =============================================================================
# Start llama-server
# =============================================================================
log_success "Starting llama-server..."
log_info "API will be available at http://${HOST}:${PORT}"
log_info "OpenAI-compatible endpoint: http://${HOST}:${PORT}/v1/chat/completions"

# Start server in background to handle signals
"${LLAMA_CMD[@]}" &
LLAMA_PID=$!

# Wait for server to be ready
log_info "Waiting for server to be ready..."
MAX_WAIT=60
WAIT_COUNT=0
while ! curl -s http://localhost:${PORT}/health > /dev/null 2>&1; do
    sleep 1
    WAIT_COUNT=$((WAIT_COUNT + 1))
    if [ ${WAIT_COUNT} -ge ${MAX_WAIT} ]; then
        log_error "Server failed to start within ${MAX_WAIT} seconds"
        log_error "Check logs for details"
        kill -TERM "$LLAMA_PID" 2>/dev/null || true
        exit 1
    fi
done

log_success "Server is ready and accepting requests!"
log_info "Expected performance on Jetson Nano 8GB:"
if [ ${OPTIMAL_GPU_LAYERS} -gt 50 ]; then
    log_info "  - Generation speed: ~12-15 tokens/second (Full GPU)"
    log_info "  - First token latency: ~200-300ms"
elif [ ${OPTIMAL_GPU_LAYERS} -gt 0 ]; then
    log_info "  - Generation speed: ~8-12 tokens/second (Partial GPU)"
    log_info "  - First token latency: ~300-400ms"
else
    log_info "  - Generation speed: ~2-3 tokens/second (CPU only)"
    log_info "  - First token latency: ~500-1000ms"
fi
log_info "  - Memory usage: ~2.8-3.5GB (typical), ~4.5GB (peak)"

# Wait for server process
wait "$LLAMA_PID"
EXIT_CODE=$?

if [ ${EXIT_CODE} -ne 0 ]; then
    log_error "llama-server exited with code ${EXIT_CODE}"
    exit ${EXIT_CODE}
fi

log_success "llama-server stopped gracefully"
exit 0
