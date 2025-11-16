#!/bin/bash
set -e

# Phase 6: Install Flux CD for GitOps
# This script installs Flux v2 on your AKS cluster

echo "🔧 Installing Flux CD..."

# Check if flux CLI is installed
if ! command -v flux &> /dev/null; then
    echo "❌ Flux CLI not found. Installing..."

    # Install flux CLI (macOS)
    if [[ "$OSTYPE" == "darwin"* ]]; then
        brew install fluxcd/tap/flux
    else
        # Linux
        curl -s https://fluxcd.io/install.sh | sudo bash
    fi
fi

# Verify flux CLI
flux --version

# Pre-flight check
echo "🔍 Running Flux pre-flight checks..."
flux check --pre

# Install Flux components
echo "🚀 Installing Flux components to the cluster..."
flux install

# Wait for Flux to be ready
echo "⏳ Waiting for Flux to be ready..."
kubectl wait --for=condition=Ready pods --all -n flux-system --timeout=300s

# Verify installation
echo "✅ Verifying Flux installation..."
flux check

echo ""
echo "✨ Flux CD installed successfully!"
echo ""
echo "Next steps:"
echo "  1. Bootstrap Flux with your Git repository:"
echo "     flux bootstrap github \\"
echo "       --owner=sholaj \\"
echo "       --repository=aso-lab \\"
echo "       --branch=main \\"
echo "       --path=./flux/clusters/lab \\"
echo "       --personal"
echo ""
echo "  2. Or use the example manifests:"
echo "     kubectl apply -f flux/git-repository.yaml"
echo "     kubectl apply -f flux/kustomization.yaml"
