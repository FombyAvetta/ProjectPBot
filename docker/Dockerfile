# OpenClaw Dockerfile for NVIDIA Jetson Nano
# Optimized for ARM64 architecture with CUDA support

FROM nvcr.io/nvidia/l4t-base:r32.7.1

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONUNBUFFERED=1
ENV OPENCLAW_HOME=/opt/openclaw

# Install system dependencies
RUN apt-get update && apt-get install -y \
    python3.8 \
    python3-pip \
    python3-dev \
    git \
    curl \
    build-essential \
    libssl-dev \
    libffi-dev \
    sqlite3 \
    libsqlite3-dev \
    && rm -rf /var/lib/apt/lists/*

# Upgrade pip and install Python dependencies
RUN python3 -m pip install --upgrade pip setuptools wheel

# Create application directory
WORKDIR ${OPENCLAW_HOME}

# Clone OpenClaw repository (or copy from local)
# If building from source, you can COPY . ${OPENCLAW_HOME} instead
RUN git clone https://github.com/getclaw/openclaw.git . || \
    echo "Note: Clone from git or use COPY command to add source"

# Install Python dependencies
# Adjust based on OpenClaw's actual requirements
RUN pip3 install --no-cache-dir \
    anthropic \
    openai \
    discord.py \
    python-telegram-bot \
    fastapi \
    uvicorn \
    pydantic \
    python-dotenv \
    aiohttp \
    requests \
    sqlalchemy \
    alembic

# Install OpenClaw package if setup.py exists
RUN if [ -f setup.py ]; then pip3 install -e .; fi

# Create data directories
RUN mkdir -p /data /logs

# Expose gateway port
EXPOSE 18789

# Set up entrypoint
COPY docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh || true

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD curl -f http://localhost:18789/health || exit 1

# Default command
CMD ["python3", "-m", "openclaw.gateway"]
