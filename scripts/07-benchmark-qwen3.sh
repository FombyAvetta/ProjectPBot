#!/bin/bash
# =============================================================================
# Qwen3 4B Performance Benchmark Script
# =============================================================================
# Comprehensive performance testing for Qwen3 on Jetson Nano 8GB
# Tests: Cold start, latency, throughput, context scaling, memory usage
# =============================================================================

set -e

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
DOCKER_DIR="${PROJECT_ROOT}/docker"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Results storage
declare -A RESULTS

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

check_service() {
    if ! docker ps --format '{{.Names}}' | grep -q "openclaw-qwen3"; then
        print_error "Qwen3 service is not running"
        print_info "Start it with: docker compose --profile qwen3 up -d qwen3-server"
        exit 1
    fi
}

# =============================================================================
# Benchmark 1: Cold Start Time
# =============================================================================
benchmark_cold_start() {
    print_header "Benchmark 1: Cold Start Time"

    print_info "Stopping Qwen3 service..."
    cd "${DOCKER_DIR}"
    docker compose stop qwen3-server > /dev/null 2>&1

    print_info "Starting service and measuring startup time..."
    local start_time=$(date +%s)
    docker compose --profile qwen3 up -d qwen3-server > /dev/null 2>&1

    # Wait for health check
    local wait_count=0
    local max_wait=120
    while [ ${wait_count} -lt ${max_wait} ]; do
        if curl -s http://localhost:8080/health > /dev/null 2>&1; then
            break
        fi
        sleep 1
        wait_count=$((wait_count + 1))
    done

    local end_time=$(date +%s)
    local cold_start_time=$((end_time - start_time))

    RESULTS["cold_start"]=${cold_start_time}

    if [ ${cold_start_time} -le 60 ]; then
        print_success "Cold start time: ${cold_start_time}s (Excellent)"
    elif [ ${cold_start_time} -le 90 ]; then
        print_success "Cold start time: ${cold_start_time}s (Good)"
    else
        print_warning "Cold start time: ${cold_start_time}s (Slow)"
    fi
}

# =============================================================================
# Benchmark 2: First Token Latency
# =============================================================================
benchmark_first_token() {
    print_header "Benchmark 2: First Token Latency"

    check_service

    print_info "Measuring time to first token..."

    local total_latency=0
    local runs=5

    for i in $(seq 1 ${runs}); do
        echo -n "  Run $i/${runs}... "

        local start_time=$(date +%s%3N)
        local response=$(curl -s -X POST http://localhost:8080/v1/chat/completions \
            -H "Content-Type: application/json" \
            -d '{
                "model": "qwen3-4b",
                "messages": [{"role": "user", "content": "Say hello"}],
                "max_tokens": 10,
                "temperature": 0.7
            }')
        local end_time=$(date +%s%3N)

        if echo "$response" | jq -e '.choices[0].message.content' > /dev/null 2>&1; then
            local latency=$((end_time - start_time))
            total_latency=$((total_latency + latency))
            echo "${latency}ms"
        else
            echo "Failed"
        fi

        sleep 2  # Cool down between runs
    done

    local avg_latency=$((total_latency / runs))
    RESULTS["first_token_latency"]=${avg_latency}

    echo ""
    if [ ${avg_latency} -le 300 ]; then
        print_success "Average first token latency: ${avg_latency}ms (Excellent)"
    elif [ ${avg_latency} -le 500 ]; then
        print_success "Average first token latency: ${avg_latency}ms (Good)"
    else
        print_warning "Average first token latency: ${avg_latency}ms (Needs tuning)"
    fi
}

# =============================================================================
# Benchmark 3: Generation Speed (Tokens/sec)
# =============================================================================
benchmark_generation_speed() {
    print_header "Benchmark 3: Generation Speed"

    check_service

    print_info "Measuring token generation speed..."

    local total_speed=0
    local runs=3

    for i in $(seq 1 ${runs}); do
        echo -n "  Run $i/${runs}... "

        local start_time=$(date +%s%3N)
        local response=$(curl -s -X POST http://localhost:8080/v1/chat/completions \
            -H "Content-Type: application/json" \
            -d '{
                "model": "qwen3-4b",
                "messages": [{"role": "user", "content": "Write a short paragraph about the moon."}],
                "max_tokens": 100,
                "temperature": 0.7
            }')
        local end_time=$(date +%s%3N)

        if echo "$response" | jq -e '.choices[0].message.content' > /dev/null 2>&1; then
            local duration=$((end_time - start_time))
            local tokens=$(echo "$response" | jq -r '.usage.completion_tokens // 0')
            if [ "$tokens" -gt 0 ]; then
                local speed=$((tokens * 1000 / duration))
                total_speed=$((total_speed + speed))
                echo "${speed} tok/s (${tokens} tokens in ${duration}ms)"
            else
                echo "No tokens"
            fi
        else
            echo "Failed"
        fi

        sleep 2
    done

    local avg_speed=$((total_speed / runs))
    RESULTS["generation_speed"]=${avg_speed}

    echo ""
    if [ ${avg_speed} -ge 12 ]; then
        print_success "Average generation speed: ${avg_speed} tok/s (Excellent - Full GPU)"
    elif [ ${avg_speed} -ge 8 ]; then
        print_success "Average generation speed: ${avg_speed} tok/s (Good - Partial GPU)"
    elif [ ${avg_speed} -ge 4 ]; then
        print_warning "Average generation speed: ${avg_speed} tok/s (Fair - Limited GPU)"
    else
        print_warning "Average generation speed: ${avg_speed} tok/s (Slow - CPU mode?)"
    fi
}

# =============================================================================
# Benchmark 4: Context Length Scaling
# =============================================================================
benchmark_context_scaling() {
    print_header "Benchmark 4: Context Length Scaling"

    check_service

    print_info "Testing different context lengths..."

    local contexts=(512 1024 2048)

    for context in "${contexts[@]}"; do
        echo -n "  Context ${context} tokens... "

        # Generate a prompt with appropriate length
        local prompt=$(python3 -c "print('word ' * int($context / 2))")

        local start_time=$(date +%s%3N)
        local response=$(curl -s -X POST http://localhost:8080/v1/chat/completions \
            -H "Content-Type: application/json" \
            -d "{
                \"model\": \"qwen3-4b\",
                \"messages\": [{\"role\": \"user\", \"content\": \"${prompt:0:1000}... summarize this\"}],
                \"max_tokens\": 50,
                \"temperature\": 0.7
            }")
        local end_time=$(date +%s%3N)

        if echo "$response" | jq -e '.choices[0].message.content' > /dev/null 2>&1; then
            local duration=$((end_time - start_time))
            echo "${duration}ms"
            RESULTS["context_${context}"]=${duration}
        else
            echo "Failed"
            RESULTS["context_${context}"]=0
        fi

        sleep 2
    done

    echo ""
    print_info "Context scaling results:"
    echo "  512 tokens:  ${RESULTS[context_512]}ms"
    echo "  1024 tokens: ${RESULTS[context_1024]}ms"
    echo "  2048 tokens: ${RESULTS[context_2048]}ms"
}

# =============================================================================
# Benchmark 5: Concurrent Request Handling
# =============================================================================
benchmark_concurrent() {
    print_header "Benchmark 5: Concurrent Request Handling"

    check_service

    print_info "Testing 3 concurrent requests..."

    local start_time=$(date +%s)

    # Launch 3 requests in parallel
    for i in 1 2 3; do
        (
            curl -s -X POST http://localhost:8080/v1/chat/completions \
                -H "Content-Type: application/json" \
                -d '{
                    "model": "qwen3-4b",
                    "messages": [{"role": "user", "content": "Count from 1 to 5"}],
                    "max_tokens": 30,
                    "temperature": 0.7
                }' > /dev/null 2>&1
        ) &
    done

    # Wait for all to complete
    wait

    local end_time=$(date +%s)
    local total_time=$((end_time - start_time))

    RESULTS["concurrent_time"]=${total_time}

    echo ""
    print_info "3 concurrent requests completed in: ${total_time}s"
    if [ ${total_time} -le 10 ]; then
        print_success "Good concurrency (likely sequential processing)"
    else
        print_warning "High latency under concurrent load"
    fi
}

# =============================================================================
# Benchmark 6: Memory Usage
# =============================================================================
benchmark_memory() {
    print_header "Benchmark 6: Memory Usage"

    check_service

    print_info "Collecting memory statistics..."

    # Container memory
    local container_mem=$(docker stats openclaw-qwen3 --no-stream --format "{{.MemUsage}}" | awk '{print $1}')
    RESULTS["container_memory"]=${container_mem}

    # System memory
    local free_mem_kb=$(grep MemAvailable /proc/meminfo | awk '{print $2}')
    local free_mem_gb=$((free_mem_kb / 1024 / 1024))
    local total_mem_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    local total_mem_gb=$((total_mem_kb / 1024 / 1024))
    local used_mem_gb=$((total_mem_gb - free_mem_gb))

    RESULTS["system_memory_used"]=${used_mem_gb}
    RESULTS["system_memory_free"]=${free_mem_gb}
    RESULTS["system_memory_total"]=${total_mem_gb}

    echo ""
    echo "  Container memory: ${container_mem}"
    echo "  System total: ${total_mem_gb}GB"
    echo "  System used: ${used_mem_gb}GB"
    echo "  System free: ${free_mem_gb}GB"

    if [ ${free_mem_gb} -ge 3 ]; then
        print_success "Healthy memory levels"
    elif [ ${free_mem_gb} -ge 2 ]; then
        print_warning "Moderate memory usage"
    else
        print_error "Critical memory usage - consider disabling other services"
    fi
}

# =============================================================================
# Benchmark 7: API Health Check
# =============================================================================
benchmark_health_check() {
    print_header "Benchmark 7: API Health Check"

    check_service

    print_info "Testing health endpoint latency..."

    local total_latency=0
    local runs=10

    for i in $(seq 1 ${runs}); do
        local latency_ms=$(curl -o /dev/null -s -w '%{time_total}\n' http://localhost:8080/health | awk '{printf "%.0f", $1*1000}')
        total_latency=$((total_latency + latency_ms))
    done

    local avg_health_latency=$((total_latency / runs))
    RESULTS["health_check_latency"]=${avg_health_latency}

    echo ""
    print_success "Average health check latency: ${avg_health_latency}ms"
}

# =============================================================================
# Results Summary
# =============================================================================
show_results() {
    print_header "Benchmark Results Summary"

    echo ""
    echo -e "${CYAN}┌─────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}│ Performance Metrics                                 │${NC}"
    echo -e "${CYAN}├─────────────────────────────────────────────────────┤${NC}"
    printf "${CYAN}│${NC} Cold Start Time:           %-25s ${CYAN}│${NC}\n" "${RESULTS[cold_start]}s"
    printf "${CYAN}│${NC} First Token Latency:       %-25s ${CYAN}│${NC}\n" "${RESULTS[first_token_latency]}ms"
    printf "${CYAN}│${NC} Generation Speed:          %-25s ${CYAN}│${NC}\n" "${RESULTS[generation_speed]} tok/s"
    printf "${CYAN}│${NC} Health Check Latency:      %-25s ${CYAN}│${NC}\n" "${RESULTS[health_check_latency]}ms"
    printf "${CYAN}│${NC} Concurrent Load (3 req):   %-25s ${CYAN}│${NC}\n" "${RESULTS[concurrent_time]}s"
    echo -e "${CYAN}├─────────────────────────────────────────────────────┤${NC}"
    echo -e "${CYAN}│ Context Scaling                                     │${NC}"
    echo -e "${CYAN}├─────────────────────────────────────────────────────┤${NC}"
    printf "${CYAN}│${NC}   512 tokens:              %-25s ${CYAN}│${NC}\n" "${RESULTS[context_512]}ms"
    printf "${CYAN}│${NC}  1024 tokens:              %-25s ${CYAN}│${NC}\n" "${RESULTS[context_1024]}ms"
    printf "${CYAN}│${NC}  2048 tokens:              %-25s ${CYAN}│${NC}\n" "${RESULTS[context_2048]}ms"
    echo -e "${CYAN}├─────────────────────────────────────────────────────┤${NC}"
    echo -e "${CYAN}│ Memory Usage                                        │${NC}"
    echo -e "${CYAN}├─────────────────────────────────────────────────────┤${NC}"
    printf "${CYAN}│${NC} Container:                 %-25s ${CYAN}│${NC}\n" "${RESULTS[container_memory]}"
    printf "${CYAN}│${NC} System Total:              %-25s ${CYAN}│${NC}\n" "${RESULTS[system_memory_total]}GB"
    printf "${CYAN}│${NC} System Used:               %-25s ${CYAN}│${NC}\n" "${RESULTS[system_memory_used]}GB"
    printf "${CYAN}│${NC} System Free:               %-25s ${CYAN}│${NC}\n" "${RESULTS[system_memory_free]}GB"
    echo -e "${CYAN}└─────────────────────────────────────────────────────┘${NC}"

    # Performance assessment
    echo ""
    print_header "Performance Assessment"

    local score=0

    # Scoring logic
    [ ${RESULTS[cold_start]} -le 60 ] && score=$((score + 15)) || score=$((score + 5))
    [ ${RESULTS[first_token_latency]} -le 400 ] && score=$((score + 20)) || score=$((score + 10))
    [ ${RESULTS[generation_speed]} -ge 10 ] && score=$((score + 30)) || [ ${RESULTS[generation_speed]} -ge 6 ] && score=$((score + 15)) || score=$((score + 5))
    [ ${RESULTS[system_memory_free]} -ge 3 ] && score=$((score + 15)) || [ ${RESULTS[system_memory_free]} -ge 2 ] && score=$((score + 5))
    [ ${RESULTS[context_2048]} -le 3000 ] && score=$((score + 10)) || score=$((score + 5))
    [ ${RESULTS[concurrent_time]} -le 15 ] && score=$((score + 10)) || score=$((score + 5))

    echo ""
    echo -e "Overall Score: ${CYAN}${score}/100${NC}"

    if [ ${score} -ge 80 ]; then
        print_success "Excellent - Optimal performance configuration"
        echo ""
        echo "Recommendations:"
        echo "  ✓ Current settings are well-optimized"
        echo "  ✓ Consider increasing context to 4096 if needed"
    elif [ ${score} -ge 60 ]; then
        print_success "Good - Acceptable performance"
        echo ""
        echo "Recommendations:"
        echo "  • Current configuration is stable"
        echo "  • Monitor memory usage during sustained load"
    elif [ ${score} -ge 40 ]; then
        print_warning "Fair - Consider tuning"
        echo ""
        echo "Recommendations:"
        echo "  • Increase GPU_LAYERS if using CPU mode"
        echo "  • Reduce CONTEXT_LENGTH to free memory"
        echo "  • Check if other services are consuming resources"
    else
        print_error "Poor - Optimization needed"
        echo ""
        echo "Recommendations:"
        echo "  ⚠ Increase GPU_LAYERS (current may be 0)"
        echo "  ⚠ Reduce CONTEXT_LENGTH to 1024"
        echo "  ⚠ Reduce BATCH_SIZE to 256"
        echo "  ⚠ Stop other services to free memory"
    fi

    # Configuration details
    echo ""
    print_header "Current Configuration"

    if [ -f "${DOCKER_DIR}/.env" ]; then
        echo "Context Length: $(grep QWEN3_CONTEXT_LENGTH ${DOCKER_DIR}/.env | cut -d'=' -f2 || echo 'Not set')"
        echo "GPU Layers: $(grep QWEN3_GPU_LAYERS ${DOCKER_DIR}/.env | cut -d'=' -f2 || echo 'Not set')"
        echo "Batch Size: $(grep QWEN3_BATCH_SIZE ${DOCKER_DIR}/.env | cut -d'=' -f2 || echo 'Not set')"
        echo "Threads: $(grep QWEN3_THREADS ${DOCKER_DIR}/.env | cut -d'=' -f2 || echo 'Not set')"
    else
        print_warning ".env file not found"
    fi
}

# =============================================================================
# Main Function
# =============================================================================
main() {
    clear
    print_header "Qwen3 4B Performance Benchmark Suite"
    print_info "Jetson Nano 8GB - Comprehensive Performance Testing"
    echo ""
    print_warning "This will take approximately 5-10 minutes"
    print_info "The service will be restarted during testing"
    echo ""
    read -p "Press Enter to start or Ctrl+C to cancel..."

    # Run all benchmarks
    benchmark_cold_start
    benchmark_first_token
    benchmark_generation_speed
    benchmark_context_scaling
    benchmark_concurrent
    benchmark_memory
    benchmark_health_check

    # Show results
    show_results

    echo ""
    print_success "Benchmark complete!"
    echo ""
}

# Run main
main
