# Frontend Dockerfile - Production Ready
# Multi-stage build: Build with Node, Serve with Nginx

# Stage 1: Build
FROM node:25-alpine as builder

WORKDIR /build

# Copy package files
COPY frontend/package.json frontend/package-lock.json ./

# Install dependencies (including dev dependencies needed for build)
RUN npm ci --silent

# Copy source code
COPY frontend/ .

# Build application
RUN npm run build

# Stage 2: Production with Nginx
FROM nginx:alpine

# Copy custom nginx config
COPY .infra/docker/nginx.conf /etc/nginx/nginx.conf

# Copy built files from builder
COPY --from=builder /build/dist /usr/share/nginx/html

# Add healthcheck script
RUN echo '#!/bin/sh' > /healthcheck.sh && \
    echo 'curl -f http://localhost:80/ || exit 1' >> /healthcheck.sh && \
    chmod +x /healthcheck.sh

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3 \
    CMD /healthcheck.sh

# Expose port
EXPOSE 80

# Start Nginx
CMD ["nginx", "-g", "daemon off;"]
