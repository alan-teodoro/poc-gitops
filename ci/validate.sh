#!/bin/bash
#
# CI Validation Script for Redis Enterprise GitOps Configuration
#
# This script validates YAML syntax and Kustomize rendering
# Run this in CI pipelines before merging changes
#

set -e  # Exit on error

echo "========================================="
echo "Redis Enterprise GitOps Validation"
echo "========================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Track validation status
VALIDATION_FAILED=0

# Function to print success
success() {
    echo -e "${GREEN}✓${NC} $1"
}

# Function to print error
error() {
    echo -e "${RED}✗${NC} $1"
    VALIDATION_FAILED=1
}

# Function to print warning
warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

# Function to print section header
section() {
    echo ""
    echo "========================================="
    echo "$1"
    echo "========================================="
}

# Check required tools
section "Checking Required Tools"

if command -v yamllint &> /dev/null; then
    success "yamllint is installed"
else
    warning "yamllint not found - skipping YAML linting"
fi

if command -v kustomize &> /dev/null; then
    success "kustomize is installed"
    KUSTOMIZE_VERSION=$(kustomize version --short 2>&1 || echo "unknown")
    echo "  Version: $KUSTOMIZE_VERSION"
else
    error "kustomize not found - please install kustomize"
    exit 1
fi

# YAML Linting
if command -v yamllint &> /dev/null; then
    section "YAML Linting"
    
    if yamllint -c ci/yamllint-config.yaml . ; then
        success "YAML linting passed"
    else
        error "YAML linting failed"
    fi
fi

# Validate Single-Environment Demo
section "Validating Single-Environment Demo (orders-redis-dev)"

if kustomize build orders-redis-dev > /dev/null 2>&1; then
    success "orders-redis-dev renders successfully"
    
    # Count resources
    RESOURCE_COUNT=$(kustomize build orders-redis-dev | grep -c "^kind:" || true)
    echo "  Resources: $RESOURCE_COUNT"
else
    error "orders-redis-dev failed to render"
fi

# Validate Multi-Environment Overlays
section "Validating Multi-Environment Overlays"

# Dev overlay
if kustomize build orders-redis/overlays/dev > /dev/null 2>&1; then
    success "orders-redis/overlays/dev renders successfully"
    RESOURCE_COUNT=$(kustomize build orders-redis/overlays/dev | grep -c "^kind:" || true)
    echo "  Resources: $RESOURCE_COUNT"
else
    error "orders-redis/overlays/dev failed to render"
fi

# Nonprod overlay
if kustomize build orders-redis/overlays/nonprod > /dev/null 2>&1; then
    success "orders-redis/overlays/nonprod renders successfully"
    RESOURCE_COUNT=$(kustomize build orders-redis/overlays/nonprod | grep -c "^kind:" || true)
    echo "  Resources: $RESOURCE_COUNT"
else
    error "orders-redis/overlays/nonprod failed to render"
fi

# Prod overlay
if kustomize build orders-redis/overlays/prod > /dev/null 2>&1; then
    success "orders-redis/overlays/prod renders successfully"
    RESOURCE_COUNT=$(kustomize build orders-redis/overlays/prod | grep -c "^kind:" || true)
    echo "  Resources: $RESOURCE_COUNT"
else
    error "orders-redis/overlays/prod failed to render"
fi

# Validate Argo CD Applications
section "Validating Argo CD Applications"

for app_file in argocd/*.yaml; do
    if [ -f "$app_file" ]; then
        if grep -q "kind: Application" "$app_file"; then
            APP_NAME=$(basename "$app_file" .yaml)
            
            # Check for placeholder repository URL
            if grep -q "your-org/poc-gitops" "$app_file"; then
                warning "$APP_NAME: Contains placeholder repository URL"
            else
                success "$APP_NAME: Repository URL configured"
            fi
        fi
    fi
done

# Policy Checks
section "Policy Checks"

# Check that production uses TLS
PROD_MANIFEST=$(kustomize build orders-redis/overlays/prod 2>/dev/null || echo "")
if echo "$PROD_MANIFEST" | grep -q "tlsMode: enabled"; then
    success "Production databases have TLS enabled"
else
    warning "Production databases should have TLS enabled"
fi

# Check that production has persistence
if echo "$PROD_MANIFEST" | grep -q "persistence: aof"; then
    success "Production databases have persistence enabled"
else
    warning "Production databases should have persistence enabled"
fi

# Summary
section "Validation Summary"

if [ $VALIDATION_FAILED -eq 0 ]; then
    echo -e "${GREEN}All validations passed!${NC}"
    exit 0
else
    echo -e "${RED}Some validations failed!${NC}"
    exit 1
fi

