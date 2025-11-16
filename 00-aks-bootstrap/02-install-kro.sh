#!/bin/bash
set -e

# ASO Lab - Phase 1: Install Kubernetes Resource Orchestrator (KRO)
# This script installs KRO for resource templating and composition

echo "🔧 Installing Kubernetes Resource Orchestrator (KRO)..."

# Install KRO using Helm
echo "📦 Getting latest KRO version..."
KRO_VERSION=$(curl -sL https://api.github.com/repos/kubernetes-sigs/kro/releases/latest | jq -r '.tag_name | ltrimstr("v")')
echo "   Installing KRO version: $KRO_VERSION"

# Install via Helm
helm install kro oci://registry.k8s.io/kro/charts/kro \
  --namespace kro \
  --create-namespace \
  --version=${KRO_VERSION}

# Wait for KRO pods to be ready
echo "⏳ Waiting for KRO pods to be ready..."
sleep 15
kubectl wait --for=condition=Ready pods --all -n kro --timeout=300s || echo "⚠️  KRO pods not ready yet"

echo ""
echo "✨ KRO installed successfully!"
echo ""
echo "Next step: Run ./03-validate-setup.sh"
