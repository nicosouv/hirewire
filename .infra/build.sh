#!/bin/bash

set -e

# Configuration
REGISTRY="ghcr.io"
REMOTE_URL=$(git config --get remote.origin.url)

# Extract owner and repo name from both SSH and HTTPS formats
if [[ "$REMOTE_URL" == git@github.com:* ]]; then
    # SSH format: git@github.com:owner/repo.git
    REPO_OWNER=$(echo "$REMOTE_URL" | sed -n 's#git@github.com:\([^/]*\)/.*#\1#p')
    REPO_NAME=$(echo "$REMOTE_URL" | sed -n 's#git@github.com:[^/]*/\([^.]*\)\.git#\1#p')
else
    # HTTPS format: https://github.com/owner/repo.git
    REPO_OWNER=$(echo "$REMOTE_URL" | sed -n 's#.*/\([^/]*\)/\([^/]*\)\.git#\1#p')
    REPO_NAME=$(echo "$REMOTE_URL" | sed -n 's#.*/\([^/]*\)/\([^/]*\)\.git#\2#p')
fi

if [ -z "$REPO_OWNER" ] || [ -z "$REPO_NAME" ]; then
    echo "Error: Could not extract repository owner and name from git remote"
    echo "Remote URL: $REMOTE_URL"
    exit 1
fi

# Get the latest stable tag from main branch
echo "Fetching latest tags..."
git fetch --tags origin main

# Get the latest tag that is reachable from main branch
LATEST_TAG=$(git describe --tags --abbrev=0 origin/main 2>/dev/null || echo "")

if [ -z "$LATEST_TAG" ]; then
    echo "Warning: No tags found on main branch, using 'latest' as tag"
    LATEST_TAG="latest"
    GIT_SHA=$(git rev-parse --short HEAD)
else
    echo "Latest stable tag: $LATEST_TAG"
    GIT_SHA=$(git rev-parse --short "$LATEST_TAG")
fi

# Image definitions (bash 3.2 compatible)
SERVICES="dbt duckdb superset"
ESSENTIAL_SERVICES="dbt duckdb"

# Function to get dockerfile for service
get_dockerfile() {
    case "$1" in
        dbt) echo ".infra/docker/dbt.Dockerfile" ;;
        duckdb) echo ".infra/docker/duckdb.Dockerfile" ;;
        superset) echo ".infra/docker/superset.Dockerfile" ;;
        *) echo "" ;;
    esac
}

# Function to check if service is in list
service_in_list() {
    local service="$1"
    local list="$2"
    for s in $list; do
        if [ "$s" = "$service" ]; then
            return 0
        fi
    done
    return 1
}

# Function to export Superset dashboards before building
export_superset_dashboards() {
    echo "🔄 Attempting to export Superset dashboards..."
    
    # Check if Superset container is running
    if docker-compose ps superset | grep -q "Up"; then
        echo "📊 Exporting dashboards from running Superset instance..."
        
        # Export dashboards
        if docker-compose exec -T superset superset export-dashboards -f /tmp/hirewire_dashboards.zip 2>/dev/null; then
            # Copy the export to build context
            docker cp "$(docker-compose ps -q superset):/tmp/hirewire_dashboards.zip" .infra/docker/hirewire_dashboards.zip
            echo "✅ Dashboards exported successfully"
        else
            echo "⚠️  Failed to export dashboards, creating empty archive"
            touch .infra/docker/hirewire_dashboards.zip
        fi
    else
        echo "⚠️  Superset not running, creating empty dashboard archive"
        touch .infra/docker/hirewire_dashboards.zip
    fi
}

# Function to build and push image
build_and_push() {
    local service=$1
    local dockerfile=$2
    local image_name="${REGISTRY}/${REPO_OWNER}/${REPO_NAME}-${service}"

    echo ""
    echo "Building ${service} image..."
    echo "Image: ${image_name}:${LATEST_TAG}"
    echo "Dockerfile: ${dockerfile}"
    
    # Special handling for Superset to export dashboards first
    if [ "$service" = "superset" ]; then
        export_superset_dashboards
    fi

    # Build with multiple tags (single platform for compatibility)
    docker build \
        --platform "linux/amd64" \
        --file "${dockerfile}" \
        --tag "${image_name}:${LATEST_TAG}" \
        --tag "${image_name}:${GIT_SHA}" \
        --tag "${image_name}:latest" \
        --build-arg BUILD_DATE=$(date -u +'%Y-%m-%dT%H:%M:%SZ') \
        --build-arg VCS_REF="${GIT_SHA}" \
        --build-arg VERSION="${LATEST_TAG}" \
        .

    if [ "$SKIP_PUSH" = true ]; then
        echo "⚠ Skipping push to registry (build-only mode)"
        echo "✓ ${service} image built successfully"
    else
        echo "Pushing ${service} image..."
        docker push "${image_name}:${LATEST_TAG}"
        docker push "${image_name}:${GIT_SHA}"
        docker push "${image_name}:latest"
        echo "✓ ${service} image pushed successfully"
    fi
}

# Check if user is logged in to GitHub Container Registry
echo "Checking GitHub Container Registry authentication..."
if ! docker info >/dev/null 2>&1; then
    echo "Error: Docker is not running or not accessible"
    exit 1
fi

# Try to check authentication by attempting to access ghcr.io
if ! echo "$GITHUB_TOKEN" | docker login ghcr.io -u "$GITHUB_USERNAME" --password-stdin 2>/dev/null; then
    echo ""
    echo "GitHub Container Registry authentication failed or not configured."
    echo ""
    echo "Please set the following environment variables:"
    echo "  export GITHUB_USERNAME=your-github-username"
    echo "  export GITHUB_TOKEN=your-personal-access-token"
    echo ""
    echo "Or login manually:"
    echo "  echo \$GITHUB_TOKEN | docker login ghcr.io -u \$GITHUB_USERNAME --password-stdin"
    echo ""
    echo "The GITHUB_TOKEN needs 'packages:write' permission"
    
    # Allow user to continue if they want to build without pushing
    echo ""
    read -p "Continue with build only (no push to registry)? [y/N]: " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
    SKIP_PUSH=true
else
    echo "✓ GitHub Container Registry authentication successful"
    SKIP_PUSH=false
fi

# Parse command line arguments
BUILD_ALL=false
BUILD_ESSENTIAL_ONLY=true

while [[ $# -gt 0 ]]; do
    case $1 in
        --all)
            BUILD_ALL=true
            BUILD_ESSENTIAL_ONLY=false
            shift
            ;;
        --essential)
            BUILD_ESSENTIAL_ONLY=true
            BUILD_ALL=false
            shift
            ;;
        --service)
            SPECIFIC_SERVICE="$2"
            BUILD_ALL=false
            BUILD_ESSENTIAL_ONLY=false
            shift 2
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --all              Build all images (dbt, duckdb, superset)"
            echo "  --essential        Build essential images only (dbt, duckdb) [default]"
            echo "  --service SERVICE  Build specific service only"
            echo "  -h, --help         Show this help message"
            echo ""
            echo "Available services: dbt, duckdb, superset"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

echo "HireWire Docker Build Script"
echo "=========================="
echo "Repository: ${REPO_OWNER}/${REPO_NAME}"
echo "Tag: ${LATEST_TAG}"
echo "SHA: ${GIT_SHA}"
echo "Registry: ${REGISTRY}"
echo ""

# Build images based on options
if [ -n "$SPECIFIC_SERVICE" ]; then
    if ! service_in_list "$SPECIFIC_SERVICE" "$SERVICES"; then
        echo "Error: Service '$SPECIFIC_SERVICE' not found"
        echo "Available services: $SERVICES"
        exit 1
    fi
    
    dockerfile=$(get_dockerfile "$SPECIFIC_SERVICE")
    echo "Building specific service: $SPECIFIC_SERVICE"
    build_and_push "$SPECIFIC_SERVICE" "$dockerfile"

elif [ "$BUILD_ALL" = true ]; then
    echo "Building all images..."
    for service in $SERVICES; do
        dockerfile=$(get_dockerfile "$service")
        build_and_push "$service" "$dockerfile"
    done

elif [ "$BUILD_ESSENTIAL_ONLY" = true ]; then
    echo "Building essential images: $ESSENTIAL_SERVICES"
    for service in $ESSENTIAL_SERVICES; do
        dockerfile=$(get_dockerfile "$service")
        build_and_push "$service" "$dockerfile"
    done
fi

echo ""
echo "✅ Build completed successfully!"
echo ""
echo "Images pushed:"
if [ "$BUILD_ALL" = true ]; then
    for service in $SERVICES; do
        echo "  - ${REGISTRY}/${REPO_OWNER}/${REPO_NAME}-${service}:${LATEST_TAG}"
    done
elif [ "$BUILD_ESSENTIAL_ONLY" = true ]; then
    for service in $ESSENTIAL_SERVICES; do
        echo "  - ${REGISTRY}/${REPO_OWNER}/${REPO_NAME}-${service}:${LATEST_TAG}"
    done
elif [ -n "$SPECIFIC_SERVICE" ]; then
    echo "  - ${REGISTRY}/${REPO_OWNER}/${REPO_NAME}-${SPECIFIC_SERVICE}:${LATEST_TAG}"
fi