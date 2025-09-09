FROM ubuntu:22.04

# Install dependencies
RUN apt-get update && apt-get install -y \
    wget \
    unzip \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Install Python and DuckDB CLI via pip for better compatibility
RUN apt-get update && apt-get install -y \
    python3 \
    python3-pip \
    && rm -rf /var/lib/apt/lists/* \
    && pip3 install duckdb==1.3.1 \
    && ln -s /usr/bin/python3 /usr/bin/python

# Create data directory
RUN mkdir -p /data

# Set working directory
WORKDIR /data

# Default command
CMD ["tail", "-f", "/dev/null"]