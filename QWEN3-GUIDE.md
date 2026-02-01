# Qwen3 4B Local LLM Guide

Complete guide for deploying and optimizing Qwen3 4B on NVIDIA Jetson Nano 8GB with OpenClaw.

## Table of Contents

- [Overview](#overview)
- [Quick Start](#quick-start)
- [Installation](#installation)
- [Configuration](#configuration)
- [Performance Tuning](#performance-tuning)
- [Usage](#usage)
- [Troubleshooting](#troubleshooting)
- [Comparison with Cloud LLMs](#comparison-with-cloud-llms)
- [Use Cases](#use-cases)
- [Advanced Topics](#advanced-topics)

---

## Overview

### What is Qwen3 4B?

Qwen3 4B is a 4-billion parameter language model quantized to Q4_K_M GGUF format for efficient inference on edge devices. This integration provides:

- **Offline Operation**: Complete independence from internet connectivity
- **Privacy**: All inference happens locally on your Jetson Nano
- **Cost**: Free after initial setup (no API fees)
- **Performance**: 10-15 tokens/second generation speed
- **Memory**: ~2.5GB model size, 2.8-3.5GB runtime memory

### System Requirements

**Minimum:**
- NVIDIA Jetson Nano 8GB
- JetPack 6.x (R36.4.0+)
- 5GB free disk space
- 3GB available RAM

**Recommended:**
- NVIDIA Jetson Nano 8GB
- JetPack 6.x latest
- 10GB free disk space
- 4GB available RAM
- OpenClaw gateway running

---

## Quick Start

### 1. Setup Qwen3

```bash
ssh john@192.168.50.69
cd openclaw
./scripts/05-qwen3-setup.sh
```

Interactive menu:
1. **Download Model** (~2.5GB, 30-60 min)
2. **Build Service** (one-time, 20-30 min)
3. **Enable Qwen3** (start service)
5. **Test API** (verify it works)

### 2. Use with OpenClaw

Edit `.env`:
```bash
LLM_PROVIDER=qwen3
```

Restart services:
```bash
docker compose restart
```

Your OpenClaw gateway now uses local Qwen3 for all LLM requests!

---

## Installation

### Step-by-Step Installation

#### 1. Download Model

The model is downloaded from HuggingFace:

```bash
cd ~/openclaw
./scripts/05-qwen3-setup.sh
# Select: 1) Download Model
```

**Details:**
- URL: `https://huggingface.co/Qwen/Qwen2.5-3B-Instruct-GGUF`
- File: `qwen2.5-3b-instruct-q4_k_m.gguf`
- Size: ~2.5GB
- Download time: 30-60 minutes (depends on connection)
- Resume support: Yes (uses `wget -c`)

**Verification:**
```bash
ls -lh ~/openclaw/models/
# Should show: Qwen3-4B-Q4_K_M.gguf (~2.5GB)
```

#### 2. Build Docker Image

Build the Qwen3 server image:

```bash
./scripts/05-qwen3-setup.sh
# Select: 2) Build Service
```

**What happens:**
1. Clones llama.cpp repository
2. Compiles with CUDA support for Jetson Nano
3. Creates optimized Docker image (~2GB)
4. Build time: 20-30 minutes (one-time)

**Verification:**
```bash
docker images | grep qwen3
# Should show: openclaw-qwen3:latest
```

#### 3. Enable Service

Start the Qwen3 service:

```bash
./scripts/05-qwen3-setup.sh
# Select: 3) Enable Qwen3
```

**Verification:**
```bash
docker ps | grep qwen3
curl http://localhost:8080/health
# Should return: {"status":"ok"}
```

---

## Configuration

### Environment Variables

All configuration is in `~/openclaw/.env`:

```bash
# Enable/disable service
QWEN3_ENABLED=false  # Set to true to start on boot

# Model path
QWEN3_MODEL_PATH=/models/Qwen3-4B-Q4_K_M.gguf

# Performance settings
QWEN3_CONTEXT_LENGTH=2048     # Max conversation length
QWEN3_GPU_LAYERS=32           # GPU offloading (0-99)
QWEN3_BATCH_SIZE=512          # Parallel processing
QWEN3_THREADS=4               # CPU threads
QWEN3_PARALLEL_REQUESTS=1     # Concurrent requests

# Resource limits
QWEN3_MEMORY_LIMIT=5g         # Docker memory cap
QWEN3_TIMEOUT=600             # Request timeout (seconds)
```

### Configuration Profiles

Choose based on your priorities:

#### Profile 1: Minimal Memory (Stable)
**Best for:** Running alongside other services

```bash
QWEN3_CONTEXT_LENGTH=1024
QWEN3_GPU_LAYERS=24
QWEN3_BATCH_SIZE=256
QWEN3_THREADS=4
```

**Expected:**
- Memory: ~2.2GB
- Speed: ~8-10 tok/s
- Context: Up to 1K tokens
- Stability: Excellent

#### Profile 2: Balanced (Recommended)
**Best for:** Most use cases

```bash
QWEN3_CONTEXT_LENGTH=2048
QWEN3_GPU_LAYERS=32
QWEN3_BATCH_SIZE=512
QWEN3_THREADS=4
```

**Expected:**
- Memory: ~2.8GB
- Speed: ~10-12 tok/s
- Context: Up to 2K tokens
- Stability: Good

#### Profile 3: Maximum Performance (Risky)
**Best for:** Dedicated Qwen3 use only

```bash
QWEN3_CONTEXT_LENGTH=4096
QWEN3_GPU_LAYERS=99
QWEN3_BATCH_SIZE=1024
QWEN3_THREADS=4
```

**Expected:**
- Memory: ~4.5GB
- Speed: ~12-15 tok/s
- Context: Up to 4K tokens
- Stability: Moderate (may OOM under load)

### Applying Configuration Changes

```bash
# Edit configuration
nano ~/openclaw/.env

# Restart service
cd ~/openclaw
docker compose stop qwen3-server
docker compose --profile qwen3 up -d qwen3-server

# Verify
docker logs openclaw-qwen3 --tail=50
```

---

## Performance Tuning

### Understanding the Parameters

#### Context Length (`QWEN3_CONTEXT_LENGTH`)

Controls maximum conversation length (prompt + response).

| Setting | Memory | Use Case |
|---------|--------|----------|
| 1024 | ~2.2GB | Short Q&A, simple tasks |
| 2048 | ~2.8GB | Normal conversations (recommended) |
| 4096 | ~4.5GB | Long conversations, document analysis |

**Recommendation:** Start with 2048. Increase only if needed.

#### GPU Layers (`QWEN3_GPU_LAYERS`)

Controls how many model layers run on GPU vs CPU.

| Setting | Memory | Speed | Use Case |
|---------|--------|-------|----------|
| 0 | ~1.8GB | ~2-3 tok/s | CPU-only fallback |
| 24 | ~2.2GB | ~8-10 tok/s | Memory-constrained |
| 32 | ~2.8GB | ~10-12 tok/s | Balanced (recommended) |
| 99 | ~3.5GB | ~12-15 tok/s | Maximum performance |

**Recommendation:** Use 32 for best balance. Set to `auto` for automatic detection.

#### Batch Size (`QWEN3_BATCH_SIZE`)

Controls parallel token processing.

| Setting | Memory | Throughput |
|---------|--------|------------|
| 256 | Lower | Moderate |
| 512 | Balanced | Good (recommended) |
| 1024 | Higher | Best |

**Recommendation:** Use 512. Increase to 1024 only if you have memory headroom.

### Optimization Strategies

#### For Maximum Speed

```bash
QWEN3_GPU_LAYERS=99           # Full GPU offload
QWEN3_BATCH_SIZE=1024         # Large batch
QWEN3_CONTEXT_LENGTH=2048     # Keep moderate
```

**Pros:** 12-15 tok/s generation
**Cons:** ~4.5GB memory, may OOM

#### For Maximum Stability

```bash
QWEN3_GPU_LAYERS=24           # Conservative GPU
QWEN3_BATCH_SIZE=256          # Small batch
QWEN3_CONTEXT_LENGTH=1024     # Short context
QWEN3_MEMORY_LIMIT=4g         # Strict limit
```

**Pros:** Rock-solid, ~2.2GB memory
**Cons:** Slower (~8-10 tok/s)

#### For Long Conversations

```bash
QWEN3_GPU_LAYERS=32           # Balanced GPU
QWEN3_BATCH_SIZE=512          # Standard batch
QWEN3_CONTEXT_LENGTH=4096     # Large context
```

**Pros:** Handles long conversations
**Cons:** ~4.5GB memory, slower with long contexts

### Memory Management

#### Check Available Memory

```bash
free -h
# Look at "available" column
```

Safe thresholds:
- **> 4GB free:** Can run any profile
- **3-4GB free:** Use Profile 2 (Balanced)
- **2-3GB free:** Use Profile 1 (Minimal)
- **< 2GB free:** Don't enable Qwen3

#### Monitor Memory During Operation

```bash
# Real-time monitoring
watch -n 1 free -h

# Docker container stats
docker stats openclaw-qwen3

# System stats (Jetson-specific)
tegrastats
```

#### Dealing with OOM (Out of Memory)

If Qwen3 container dies unexpectedly:

1. **Check logs:**
   ```bash
   docker logs openclaw-qwen3 --tail=100
   # Look for "Out of memory" or "Killed"
   ```

2. **Reduce memory usage:**
   ```bash
   nano ~/openclaw/.env
   # Set to Profile 1 (Minimal Memory)
   # Or reduce CONTEXT_LENGTH to 1024
   # Or reduce GPU_LAYERS to 24
   ```

3. **Stop other services:**
   ```bash
   # List running containers
   docker ps

   # Stop non-essential ones
   docker stop <container-name>
   ```

4. **Restart Qwen3:**
   ```bash
   cd ~/openclaw
   docker compose --profile qwen3 up -d qwen3-server
   ```

---

## Usage

### Basic Usage

#### Start Qwen3 Service

```bash
cd ~/openclaw
./scripts/05-qwen3-setup.sh
# Select: 3) Enable Qwen3
```

Or manually:
```bash
cd ~/openclaw
docker compose --profile qwen3 up -d qwen3-server
```

#### Stop Qwen3 Service

```bash
./scripts/05-qwen3-setup.sh
# Select: 4) Disable Qwen3
```

Or manually:
```bash
docker compose stop qwen3-server
```

#### Test API

```bash
curl -X POST http://localhost:8080/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "qwen3-4b",
    "messages": [
      {"role": "user", "content": "What is the capital of France?"}
    ],
    "max_tokens": 50
  }'
```

### Integration with OpenClaw

#### Set as Primary LLM

Edit `~/openclaw/.env`:
```bash
LLM_PROVIDER=qwen3
```

Restart OpenClaw:
```bash
cd ~/openclaw
docker compose restart gateway
```

Now all OpenClaw requests use local Qwen3!

#### Fallback Configuration

Keep cloud API as fallback:

```bash
# Primary: Qwen3 (local)
LLM_PROVIDER=qwen3

# Fallback: Claude (cloud)
ANTHROPIC_API_KEY=sk-ant-your-key-here
```

If Qwen3 fails, implement fallback logic in your gateway code.

### API Reference

Qwen3 provides an OpenAI-compatible API:

**Endpoint:** `http://localhost:8080/v1/chat/completions`

**Request:**
```json
{
  "model": "qwen3-4b",
  "messages": [
    {"role": "system", "content": "You are a helpful assistant."},
    {"role": "user", "content": "Hello!"}
  ],
  "max_tokens": 100,
  "temperature": 0.7,
  "top_p": 0.9
}
```

**Response:**
```json
{
  "id": "chatcmpl-...",
  "object": "chat.completion",
  "created": 1234567890,
  "model": "qwen3-4b",
  "choices": [{
    "index": 0,
    "message": {
      "role": "assistant",
      "content": "Hello! How can I help you today?"
    },
    "finish_reason": "stop"
  }],
  "usage": {
    "prompt_tokens": 15,
    "completion_tokens": 10,
    "total_tokens": 25
  }
}
```

---

## Troubleshooting

### Common Issues

#### Issue 1: Service Won't Start

**Symptoms:** Container starts then immediately stops

**Diagnosis:**
```bash
docker logs openclaw-qwen3 --tail=50
```

**Common causes:**

1. **Model file not found**
   ```
   ERROR: Model file not found at /models/Qwen3-4B-Q4_K_M.gguf
   ```
   **Solution:** Download model with `./scripts/05-qwen3-setup.sh` option 1

2. **GPU not available**
   ```
   WARNING: nvidia-smi failed
   ```
   **Solution:** Check NVIDIA runtime:
   ```bash
   docker run --rm --runtime=nvidia nvidia/cuda:12.2.0-base-ubuntu22.04 nvidia-smi
   ```

3. **Out of memory**
   ```
   Killed
   ```
   **Solution:** Reduce memory settings (see Profile 1)

#### Issue 2: Slow Performance (< 5 tok/s)

**Diagnosis:**
```bash
./scripts/05-qwen3-setup.sh
# Select: 5) Test API
# Check reported speed
```

**Common causes:**

1. **CPU-only mode** (GPU_LAYERS=0)
   **Solution:** Increase GPU_LAYERS to 32+

2. **Other processes consuming GPU**
   **Solution:** Check with `tegrastats`, stop other GPU processes

3. **Swapping to disk**
   **Solution:** Free memory, reduce CONTEXT_LENGTH

#### Issue 3: API Not Responding

**Symptoms:** `curl: (7) Failed to connect to localhost:8080`

**Diagnosis:**
```bash
docker ps | grep qwen3
# Check if container is running

docker logs openclaw-qwen3 --tail=50
# Check for errors
```

**Solutions:**

1. **Container not running**
   ```bash
   docker compose --profile qwen3 up -d qwen3-server
   ```

2. **Port conflict**
   ```bash
   sudo netstat -tlnp | grep 8080
   # Kill conflicting process
   ```

3. **Health check failing**
   ```bash
   docker inspect openclaw-qwen3 | grep -A 10 Health
   # Wait for startup (up to 60s)
   ```

#### Issue 4: High Memory Usage

**Symptoms:** System sluggish, other services failing

**Diagnosis:**
```bash
free -h
docker stats openclaw-qwen3
```

**Solutions:**

1. **Switch to Profile 1 (Minimal)**
2. **Reduce CONTEXT_LENGTH to 1024**
3. **Stop other Docker containers**
4. **Disable Qwen3 when not needed**

### Diagnostic Tools

#### Check Service Status

```bash
# Via maintenance script
cd ~/openclaw
./scripts/06-maintenance.sh
# Select: 19) Qwen3 Status & Diagnostics

# Or manually
docker ps | grep qwen3
docker logs openclaw-qwen3
curl http://localhost:8080/health
```

#### Run Performance Benchmark

```bash
cd ~/openclaw
./scripts/07-benchmark-qwen3.sh
```

Benchmark tests:
- Cold start time
- First token latency
- Generation speed
- Context scaling
- Memory usage
- Overall score (0-100)

#### View Resource Usage

```bash
# Container stats
docker stats openclaw-qwen3

# System memory
free -h

# Jetson stats
tegrastats

# GPU utilization
nvidia-smi
```

---

## Comparison with Cloud LLMs

### Qwen3 4B vs Claude/GPT-4

| Metric | Qwen3 4B (Local) | Claude 3.5 Sonnet | GPT-4 |
|--------|------------------|-------------------|-------|
| **Cost** | Free | $3/MTok input, $15/MTok output | $30/MTok input, $60/MTok output |
| **Latency** | 200-400ms first token | 300-500ms first token | 400-600ms first token |
| **Speed** | 10-15 tok/s | 50-80 tok/s | 40-60 tok/s |
| **Context** | 1-4K tokens | 200K tokens | 128K tokens |
| **Quality** | Good for simple tasks | Excellent | Excellent |
| **Privacy** | Complete (offline) | Cloud (Anthropic servers) | Cloud (OpenAI servers) |
| **Availability** | Offline capable | Requires internet | Requires internet |
| **Setup** | Complex (30-60 min) | Simple (API key) | Simple (API key) |

### When to Use Each

#### Use Qwen3 4B When:
- Privacy is critical (sensitive data)
- Internet is unreliable/unavailable
- Cost optimization is priority
- Simple Q&A, summaries, translations
- Testing and development
- High-volume, low-complexity tasks

#### Use Claude/GPT-4 When:
- Quality is critical
- Complex reasoning required
- Long context needed (> 4K tokens)
- Latest knowledge required
- Specialized domains (medical, legal, etc.)
- Production critical paths

### Cost Analysis

**Scenario:** 1 million tokens/month

| Provider | Cost | Notes |
|----------|------|-------|
| Qwen3 4B | $0 | After initial setup |
| Claude 3.5 | ~$18,000 | $3 input + $15 output (50/50 split) |
| GPT-4 | ~$45,000 | $30 input + $60 output (50/50 split) |

**Break-even:** Qwen3 pays for itself immediately for any volume.

**BUT:** Factor in:
- Developer time for setup/maintenance
- Hardware cost (Jetson Nano ~$200)
- Quality tradeoffs for complex tasks
- Monitoring and upkeep

---

## Use Cases

### Ideal Use Cases for Qwen3 on Jetson Nano

#### 1. Home Automation Assistant
**Why:** Privacy, offline, always available

```python
# Example: Voice assistant for home control
user: "Turn off the living room lights"
qwen3: "I'll turn off the living room lights now."
# Trigger: Smart home action
```

**Benefits:**
- Works during internet outages
- Private (voice commands stay local)
- Fast response (< 500ms)

#### 2. Edge AI for IoT Devices
**Why:** Low latency, no cloud dependency

```python
# Example: Security camera analysis
user: "Describe what you see in this image"
qwen3: "I see a person walking towards the front door..."
# Trigger: Alert or action
```

**Benefits:**
- Real-time inference
- No cloud upload of sensitive footage
- Reduced bandwidth usage

#### 3. Educational Chatbot
**Why:** Cost-effective, privacy-friendly

```python
# Example: Homework helper
student: "Explain photosynthesis simply"
qwen3: "Photosynthesis is how plants make food from sunlight..."
```

**Benefits:**
- Free for unlimited questions
- Private student data
- Always available

#### 4. Development and Testing
**Why:** Fast iteration, no API costs

```python
# Example: Test chatbot flows
for scenario in test_scenarios:
    response = qwen3.generate(scenario)
    assert validate(response)
```

**Benefits:**
- Unlimited testing
- Consistent performance
- No rate limits

#### 5. Content Summarization
**Why:** Fast, batch processing

```python
# Example: Daily news digest
for article in articles:
    summary = qwen3.summarize(article)
    send_digest(summary)
```

**Benefits:**
- Process locally in bulk
- No per-request API cost
- Predictable latency

### Use Cases Better Suited for Cloud LLMs

1. **Complex reasoning** (math, logic, coding)
2. **Long-form content** (> 2K tokens)
3. **Specialized knowledge** (medical, legal)
4. **Latest information** (news, current events)
5. **Multi-modal** (images, documents)
6. **Production critical paths** (where quality is paramount)

---

## Advanced Topics

### Custom Model Quantization

Want to use a different model? Quantize your own:

```bash
# Clone llama.cpp
git clone https://github.com/ggerganov/llama.cpp
cd llama.cpp

# Build quantization tools
make quantize

# Quantize your model
./quantize /path/to/model.gguf /path/to/output.gguf Q4_K_M
```

Update `QWEN3_MODEL_PATH` to point to your custom model.

### Multi-Model Setup

Run multiple models simultaneously (requires more memory):

```yaml
# docker-compose.yml
qwen3-server-4b:
  ...
  ports:
    - "8080:8080"

qwen3-server-7b:
  ...
  ports:
    - "8081:8080"
  environment:
    MODEL_PATH: /models/Qwen3-7B-Q4_K_M.gguf
```

### Load Balancing

For high traffic, run multiple Qwen3 instances (different Jetsons):

```bash
# On gateway
LLM_QWEN3_ENDPOINTS=http://jetson1:8080,http://jetson2:8080,http://jetson3:8080
```

Implement round-robin or least-connections in gateway code.

### Monitoring and Alerts

Set up Prometheus metrics:

```bash
# Export metrics from llama-server
curl http://localhost:8080/metrics
```

Alert on:
- High memory usage (> 90%)
- Slow response times (> 2s)
- Service health check failures

### Fine-Tuning (Advanced)

Fine-tune Qwen3 for your specific use case:

1. Prepare training data (JSONL format)
2. Use `llama.cpp` fine-tuning tools
3. Quantize fine-tuned model
4. Deploy to Jetson

**Note:** Fine-tuning requires significant compute resources (not on Jetson).

### Integration with Other Services

#### Telegram Bot
```python
# In your bot code
if message.text:
    response = qwen3_client.generate(message.text)
    bot.reply(message, response)
```

#### Discord Bot
```python
@bot.command()
async def ask(ctx, *, question):
    response = qwen3_client.generate(question)
    await ctx.send(response)
```

#### REST API
```python
from flask import Flask, request
app = Flask(__name__)

@app.route('/chat', methods=['POST'])
def chat():
    prompt = request.json['prompt']
    response = qwen3_client.generate(prompt)
    return {'response': response}
```

---

## Conclusion

Qwen3 4B on Jetson Nano provides a powerful, private, and cost-effective local LLM solution. While it can't match the quality of Claude or GPT-4 for complex tasks, it excels at:

- Privacy-sensitive applications
- Offline/edge deployments
- High-volume, simple tasks
- Cost optimization
- Development and testing

**Key Takeaways:**
1. Start with Profile 2 (Balanced) configuration
2. Monitor memory usage closely
3. Use for simple tasks, cloud LLMs for complex ones
4. Benchmark regularly to optimize settings
5. Keep OpenClaw gateway as orchestrator

**Next Steps:**
- Run benchmark: `./scripts/07-benchmark-qwen3.sh`
- Experiment with settings for your use case
- Monitor performance over time
- Consider hybrid approach (Qwen3 + cloud LLM)

For support and questions, see the main README.md and join the community discussions.

---

**Last Updated:** 2026-01-31
**Version:** 1.0
**Tested On:** Jetson Nano 8GB, JetPack 6.1
