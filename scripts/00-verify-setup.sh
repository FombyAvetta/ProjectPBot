#!/bin/bash
#
# 00-verify-setup.sh
# Verify local deployment setup before deploying to Jetson
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

ERRORS=0
WARNINGS=0

print_check() {
    echo -n "Checking $1... "
}

print_ok() {
    echo -e "${GREEN}✓${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
    ((ERRORS++))
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
    ((WARNINGS++))
}

echo "=========================================="
echo "OpenClaw Deployment Setup Verification"
echo "=========================================="
echo ""

# Check directory structure
print_check "directory structure"
if [ -d "docker" ] && [ -d "scripts" ]; then
    print_ok
else
    print_error "Missing docker/ or scripts/ directory"
fi

# Check required scripts
print_check "deployment scripts"
REQUIRED_SCRIPTS=(
    "scripts/01-ssh-setup.sh"
    "scripts/02-docker-install.sh"
    "scripts/03-openclaw-build.sh"
    "scripts/04-configure-channels.sh"
    "scripts/06-maintenance.sh"
    "deploy.sh"
)

MISSING=0
for script in "${REQUIRED_SCRIPTS[@]}"; do
    if [ ! -f "$script" ]; then
        echo -e "${RED}Missing: $script${NC}"
        ((MISSING++))
        ((ERRORS++))
    fi
done

if [ $MISSING -eq 0 ]; then
    print_ok
fi

# Check script permissions
print_check "script permissions"
NON_EXEC=0
for script in "${REQUIRED_SCRIPTS[@]}"; do
    if [ -f "$script" ] && [ ! -x "$script" ]; then
        echo -e "${YELLOW}Not executable: $script${NC}"
        ((NON_EXEC++))
        ((WARNINGS++))
    fi
done

if [ $NON_EXEC -eq 0 ]; then
    print_ok
else
    echo "Run: chmod +x ${REQUIRED_SCRIPTS[@]}"
fi

# Check Docker files
print_check "Docker configuration files"
DOCKER_FILES=(
    "docker/Dockerfile"
    "docker/docker-compose.yml"
    "docker/.env.example"
    "docker/docker-entrypoint.sh"
)

MISSING_DOCKER=0
for file in "${DOCKER_FILES[@]}"; do
    if [ ! -f "$file" ]; then
        echo -e "${RED}Missing: $file${NC}"
        ((MISSING_DOCKER++))
        ((ERRORS++))
    fi
done

if [ $MISSING_DOCKER -eq 0 ]; then
    print_ok
fi

# Check documentation
print_check "documentation files"
if [ -f "README.md" ] && [ -f "QUICKSTART.md" ]; then
    print_ok
else
    print_warning "Missing documentation files"
fi

# Check local prerequisites
echo ""
echo "Checking local prerequisites..."

print_check "ssh command"
if command -v ssh &> /dev/null; then
    print_ok
else
    print_error "ssh not found"
fi

print_check "rsync command"
if command -v rsync &> /dev/null; then
    print_ok
else
    print_error "rsync not found (install with: brew install rsync)"
fi

print_check "git command"
if command -v git &> /dev/null; then
    print_ok
else
    print_warning "git not found"
fi

print_check "curl command"
if command -v curl &> /dev/null; then
    print_ok
else
    print_warning "curl not found"
fi

# Check git status
if [ -d ".git" ]; then
    echo ""
    echo "Git repository status:"

    # Check for uncommitted changes
    if git diff-index --quiet HEAD -- 2>/dev/null; then
        echo -e "${GREEN}✓ No uncommitted changes${NC}"
    else
        echo -e "${YELLOW}⚠ You have uncommitted changes${NC}"
        echo "Consider committing before deployment:"
        echo "  git add ."
        echo "  git commit -m 'Add OpenClaw deployment scripts'"
    fi
fi

# Summary
echo ""
echo "=========================================="
echo "Verification Summary"
echo "=========================================="
echo ""

if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo -e "${GREEN}✓ All checks passed!${NC}"
    echo ""
    echo "You're ready to deploy. Run:"
    echo "  ./deploy.sh"
elif [ $ERRORS -eq 0 ]; then
    echo -e "${YELLOW}Warnings: $WARNINGS${NC}"
    echo -e "${GREEN}Errors: 0${NC}"
    echo ""
    echo "You can proceed with deployment, but check warnings above."
    echo ""
    echo "To deploy, run:"
    echo "  ./deploy.sh"
else
    echo -e "${RED}Errors: $ERRORS${NC}"
    echo -e "${YELLOW}Warnings: $WARNINGS${NC}"
    echo ""
    echo "Please fix errors before deploying."
    exit 1
fi

echo ""
echo "Next steps:"
echo "  1. ./deploy.sh                    # Deploy to Jetson"
echo "  2. Edit ~/openclaw/.env on Jetson # Add API keys"
echo "  3. Configure channels              # Add Telegram/Discord bots"
echo ""
