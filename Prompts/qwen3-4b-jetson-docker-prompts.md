# Claude Code Prompts: Qwen3 4B on Jetson Orin Nano (Docker)

A collection of prompts for deploying Qwen3 4B (INT4 Q4_K_M GGUF) in Docker on Jetson Orin Nano 8GB.

---

## 🚀 Quick Start Prompts

### Prompt 1: Full Setup (One-Shot)
```
Set up Qwen3 4B (Q4_K_M GGUF quantization) running in a Docker container on my Jetson Orin Nano 8GB with these requirements:

1. Use the official NVIDIA L4T base image compatible with JetPack 6.2
2. Build llama.cpp with CUDA support inside the container
3. Download the Qwen3-4B-Q4_K_M.gguf model from Hugging Face
4. Expose an OpenAI-compatible API on port 8080
5. Configure for optimal performance (Super mode settings, GPU offloading)
6. Include health checks and automatic restart
7. Mount a volume for model persistence

Create all necessary files: Dockerfile, docker-compose.yml, and a startup script. Optimize for the 8GB unified memory constraint.
```

---

## 📁 Individual Setup Prompts

### Prompt 2: Create Optimized Dockerfile
```
Create a Dockerfile for running Qwen3 4B on Jetson Orin Nano with these specifications:

Base image: nvcr.io/nvidia/l4t-jetpack:r36.4.0 (or latest JetPack 6.x)

Build steps:
- Install build dependencies (cmake, git, ccache)
- Clone and compile llama.cpp with GGML_CUDA=ON
- Create a non-root user for security
- Set up model directory at /models
- Configure environment for CUDA and optimal memory usage

Runtime:
- Expose port 8080 for the API server
- Set CUDA_VISIBLE_DEVICES=0
- Default to running llama-server with sensible defaults for 8GB RAM

Include multi-stage build to minimize final image size. Add labels for version tracking.
```

### Prompt 3: Create Docker Compose Configuration
```
Create a docker-compose.yml for Qwen3 4B on Jetson Orin Nano with:

Services:
- qwen3-server: The main LLM inference service

Configuration:
- Use NVIDIA runtime for GPU access
- Deploy with memory limits (6GB max to leave system headroom)
- Mount ./models:/models for model persistence
- Mount ./logs:/app/logs for logging
- Environment variables for model path, context length (4096), GPU layers (99)
- Restart policy: unless-stopped
- Health check hitting /health endpoint every 30s

Include a .env.example file with all configurable parameters documented.
```

### Prompt 4: Create Model Download Script
```
Create a shell script download-model.sh that:

1. Checks if running on Jetson (validates /etc/nv_tegra_release exists)
2. Creates ./models directory if not exists
3. Downloads Qwen3-4B-Q4_K_M.gguf from Hugging Face using wget with:
   - Resume support (-c flag)
   - Progress bar
   - Retry on failure (3 attempts)
4. Verifies file integrity with SHA256 checksum
5. Sets appropriate permissions
6. Reports final file size and confirms readiness

Include error handling and helpful status messages. Make it idempotent (skip if model already exists and valid).
```

### Prompt 5: Create Startup/Entrypoint Script
```
Create an entrypoint.sh script for the Qwen3 4B Docker container that:

1. Validates the model file exists at $MODEL_PATH
2. Checks available GPU memory using nvidia-smi or tegrastats
3. Auto-calculates optimal settings based on available memory:
   - Context length (default 4096, reduce if memory tight)
   - Batch size
   - Number of GPU layers
4. Starts llama-server with:
   - Host 0.0.0.0, port 8080
   - Model path from environment
   - Computed optimal parameters
   - Chat template for Qwen3
   - Logging to stdout for Docker logs
5. Handles SIGTERM gracefully for clean shutdown

Include helpful startup banner showing configuration being used.
```

---

## 🔧 System Preparation Prompts

### Prompt 6: Jetson System Optimization Script
```
Create a shell script prepare-jetson.sh that prepares a Jetson Orin Nano 8GB for running Qwen3 4B:

System optimizations:
1. Enable Super mode (nvpmodel -m 2) if available
2. Lock clocks at maximum (jetson_clocks)
3. Configure 16GB swap on NVMe/SD card
4. Disable zram (nvzramconfig)
5. Set GPU memory growth limits

Docker setup:
1. Install NVIDIA Container Toolkit if not present
2. Configure Docker default runtime as nvidia
3. Test GPU access in container

Verification:
1. Print system info (JetPack version, available memory, GPU info)
2. Run a quick CUDA test
3. Confirm Docker can access GPU

Make it safe to run multiple times (idempotent). Require sudo and confirm before making changes.
```

### Prompt 7: Memory Monitoring Script
```
Create a monitoring script monitor-qwen3.sh that runs alongside the Qwen3 container:

Monitors:
- GPU memory usage (from tegrastats)
- CPU and system memory usage
- Container memory consumption
- Inference throughput (requests to /health or /metrics)
- Temperature (GPU and CPU)

Features:
- Updates every 2 seconds
- Color-coded warnings (yellow >70%, red >90% memory)
- Logs to file with timestamps
- Optional alert when memory exceeds threshold
- Clean terminal UI using printf/tput

Can be run with: ./monitor-qwen3.sh [--log filename] [--alert-threshold 85]
```

---

## 🌐 API & Integration Prompts

### Prompt 8: OpenAI-Compatible API Wrapper
```
The llama.cpp server provides an OpenAI-compatible API. Create a simple Python test client test-qwen3-api.py that:

1. Connects to http://localhost:8080
2. Lists available models via /v1/models
3. Sends a test chat completion request to /v1/chat/completions with:
   - Model: "qwen3-4b"
   - A simple test prompt
   - Temperature 0.7, max_tokens 256
4. Streams the response and prints tokens as received
5. Reports timing statistics (time to first token, total time, tokens/sec)

Include error handling for connection refused, timeouts, and API errors. Use only standard library + requests (no langchain/openai SDK).
```

### Prompt 9: Nginx Reverse Proxy Configuration
```
Create nginx configuration and Docker setup to put Qwen3 API behind a reverse proxy:

Features:
- SSL termination (with self-signed cert generation script)
- Rate limiting (10 requests/minute per IP)
- Request size limits (prevent huge context attacks)
- Basic auth option
- CORS headers for web frontend access
- Proxy buffering disabled for streaming responses
- Health check endpoint passthrough

Files needed:
- nginx.conf
- Addition to docker-compose.yml for nginx service
- Script to generate self-signed certs
- .htpasswd generation instructions
```

---

## 🐛 Debugging & Troubleshooting Prompts

### Prompt 10: Diagnostic Script
```
Create a diagnostic script diagnose-qwen3.sh that helps troubleshoot Qwen3 on Jetson:

Checks:
1. JetPack version compatibility (needs 6.x)
2. Docker and nvidia-container-toolkit installation
3. GPU accessibility (nvidia-smi, can Docker see GPU)
4. Available memory (system + swap)
5. Model file exists and is valid GGUF
6. Port 8080 availability
7. Container logs (last 50 lines if running)
8. Network connectivity to HuggingFace (for model download)
9. Disk space for models and Docker

Output:
- Clear PASS/FAIL for each check
- Suggested fixes for failures
- System info summary at the end
- Option to output as JSON for automation

Run with: ./diagnose-qwen3.sh [--json] [--fix]
```

### Prompt 11: Performance Benchmark Script
```
Create a benchmark script benchmark-qwen3.sh that tests Qwen3 4B performance:

Tests:
1. Cold start time (container start to first response)
2. Prompt processing speed (tokens/sec) with various prompt lengths (100, 500, 1000, 2000 tokens)
3. Generation speed (tokens/sec) for 100, 256, 512 token outputs
4. Concurrent request handling (1, 2, 4 simultaneous requests)
5. Memory usage at different context lengths

Output:
- Results table with all metrics
- Comparison to expected performance (flag if significantly below)
- JSON export option for tracking over time
- Recommendations based on results

Use curl for API calls, tegrastats for memory monitoring. Include warmup requests before measuring.
```

---

## 📦 Complete Project Structure Prompt

### Prompt 12: Generate Full Project
```
Create a complete project structure for deploying Qwen3 4B on Jetson Orin Nano in Docker:

qwen3-jetson/
├── README.md                 # Setup instructions and usage guide
├── Dockerfile               # Multi-stage build for llama.cpp
├── docker-compose.yml       # Main deployment config
├── .env.example             # Environment variables template
├── scripts/
│   ├── prepare-jetson.sh    # System preparation
│   ├── download-model.sh    # Model downloader
│   ├── start.sh             # Quick start script
│   ├── stop.sh              # Clean shutdown
│   ├── logs.sh              # View container logs
│   ├── monitor.sh           # Resource monitoring
│   ├── diagnose.sh          # Troubleshooting
│   └── benchmark.sh         # Performance testing
├── config/
│   ├── llama-server.conf    # Server configuration
│   └── nginx.conf           # Optional reverse proxy
├── models/
│   └── .gitkeep             # Model directory (gitignored)
└── tests/
    ├── test-api.py          # API test client
    └── test-chat.sh         # Quick curl-based test

Include comprehensive README with:
- Hardware requirements
- Quick start (3 commands)
- Configuration options
- Troubleshooting FAQ
- Performance expectations
- API documentation
```

---

## 💡 Usage Tips

1. **Start simple**: Use Prompt 1 for a quick one-shot setup, then refine with individual prompts.

2. **Memory is critical**: Always run `prepare-jetson.sh` first to configure swap and Super mode.

3. **Test incrementally**: Use `diagnose-qwen3.sh` after each major change.

4. **Monitor resources**: Keep `monitor-qwen3.sh` running in a separate terminal during development.

5. **Context length tradeoff**: Start with 2048 context, increase to 4096 only if memory allows.

---

## 🔗 Reference Links

- [Qwen3 4B GGUF Models](https://huggingface.co/Qwen/Qwen3-4B-GGUF)
- [llama.cpp GitHub](https://github.com/ggerganov/llama.cpp)
- [NVIDIA L4T Containers](https://catalog.ngc.nvidia.com/orgs/nvidia/containers/l4t-jetpack)
- [JetPack 6.2 Release Notes](https://developer.nvidia.com/embedded/jetpack-sdk-62)
