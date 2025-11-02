#!/bin/bash
# Release Helper Script
# Creates a new semantic version tag and pushes it to trigger CI/CD

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Functions
print_help() {
    echo -e "${BLUE}🚀 HireWire Release Helper${NC}"
    echo ""
    echo "Usage: ./scripts/release.sh [VERSION] [--dry-run]"
    echo ""
    echo "Examples:"
    echo "  ./scripts/release.sh 1.2.3        # Create release v1.2.3"
    echo "  ./scripts/release.sh minor        # Bump minor version"
    echo "  ./scripts/release.sh patch        # Bump patch version"
    echo "  ./scripts/release.sh --dry-run    # Test without creating tag"
    echo ""
    echo "Semantic Versioning:"
    echo "  major  - Breaking changes (1.0.0 -> 2.0.0)"
    echo "  minor  - New features (1.0.0 -> 1.1.0)"
    echo "  patch  - Bug fixes (1.0.0 -> 1.0.1)"
}

get_current_version() {
    git describe --tags --abbrev=0 2>/dev/null | sed 's/v//' || echo "0.0.0"
}

bump_version() {
    local version=$1
    local type=$2

    IFS='.' read -ra PARTS <<< "$version"
    local major=${PARTS[0]}
    local minor=${PARTS[1]}
    local patch=${PARTS[2]}

    case $type in
        major)
            echo "$((major + 1)).0.0"
            ;;
        minor)
            echo "${major}.$((minor + 1)).0"
            ;;
        patch)
            echo "${major}.${minor}.$((patch + 1))"
            ;;
        *)
            echo "$type"
            ;;
    esac
}

validate_version() {
    if [[ ! $1 =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo -e "${RED}❌ Invalid version format. Use: X.Y.Z${NC}"
        exit 1
    fi
}

detect_changes() {
    local last_tag=$(git describe --tags --abbrev=0 2>/dev/null || echo "")

    if [ -z "$last_tag" ]; then
        echo -e "${YELLOW}⚠️  No previous tag found - this is the first release${NC}"
        return
    fi

    echo -e "${BLUE}📊 Changes since ${last_tag}:${NC}"
    echo ""

    # Check backend changes
    if git diff --name-only $last_tag HEAD | grep -q '^backend/'; then
        echo -e "${GREEN}✅ Backend${NC} - Changes detected"
    else
        echo -e "   Backend - No changes"
    fi

    # Check frontend changes
    if git diff --name-only $last_tag HEAD | grep -q '^frontend/'; then
        echo -e "${GREEN}✅ Frontend${NC} - Changes detected"
    else
        echo -e "   Frontend - No changes"
    fi

    # Check airflow changes
    if git diff --name-only $last_tag HEAD | grep -q '^airflow/'; then
        echo -e "${GREEN}✅ Airflow${NC} - Changes detected"
    else
        echo -e "   Airflow - No changes"
    fi

    # Check DBT changes
    if git diff --name-only $last_tag HEAD | grep -q '^dbt_project/\|^profiles/'; then
        echo -e "${GREEN}✅ DBT${NC} - Changes detected"
    else
        echo -e "   DBT - No changes"
    fi

    echo ""
}

# Main script
main() {
    # Check if in git repo
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        echo -e "${RED}❌ Not in a git repository${NC}"
        exit 1
    fi

    # Check for uncommitted changes
    if ! git diff-index --quiet HEAD --; then
        echo -e "${RED}❌ Uncommitted changes detected. Commit or stash them first.${NC}"
        exit 1
    fi

    # Parse arguments
    DRY_RUN=false
    VERSION_ARG=""

    for arg in "$@"; do
        case $arg in
            --help|-h)
                print_help
                exit 0
                ;;
            --dry-run)
                DRY_RUN=true
                ;;
            *)
                VERSION_ARG="$arg"
                ;;
        esac
    done

    # Get current version
    CURRENT_VERSION=$(get_current_version)
    echo -e "${BLUE}Current version: ${CURRENT_VERSION}${NC}"

    # Determine new version
    if [ -z "$VERSION_ARG" ]; then
        echo -e "${YELLOW}No version specified. Using patch bump.${NC}"
        NEW_VERSION=$(bump_version "$CURRENT_VERSION" "patch")
    elif [[ "$VERSION_ARG" =~ ^(major|minor|patch)$ ]]; then
        NEW_VERSION=$(bump_version "$CURRENT_VERSION" "$VERSION_ARG")
    else
        NEW_VERSION="$VERSION_ARG"
    fi

    # Validate version
    validate_version "$NEW_VERSION"

    echo -e "${GREEN}New version: ${NEW_VERSION}${NC}"
    echo ""

    # Detect changes
    detect_changes

    # Confirm
    if [ "$DRY_RUN" = true ]; then
        echo -e "${YELLOW}🧪 DRY RUN - No changes will be made${NC}"
        exit 0
    fi

    echo -e "${YELLOW}⚠️  This will create tag v${NEW_VERSION} and trigger CI/CD${NC}"
    read -p "Continue? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${RED}Aborted${NC}"
        exit 1
    fi

    # Create tag
    echo -e "${BLUE}Creating tag v${NEW_VERSION}...${NC}"
    git tag -a "v${NEW_VERSION}" -m "Release v${NEW_VERSION}"

    # Push tag
    echo -e "${BLUE}Pushing tag to remote...${NC}"
    git push origin "v${NEW_VERSION}"

    echo ""
    echo -e "${GREEN}✅ Release v${NEW_VERSION} created successfully!${NC}"
    echo ""
    echo "🔗 GitHub Actions will now:"
    echo "  1. Run tests"
    echo "  2. Build Docker images for changed services"
    echo "  3. Push images to GHCR"
    echo "  4. Create GitHub Release"
    echo ""
    echo "Monitor progress at:"
    echo "  https://github.com/$(git config --get remote.origin.url | sed 's/.*github.com[:/]\(.*\)\.git/\1/')/actions"
}

# Run main
main "$@"
