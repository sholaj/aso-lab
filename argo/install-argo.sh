#!/bin/bash
set -e

# Phase 6: Install Argo CD for GitOps (Alternative to Flux)
# This script installs Argo CD on your AKS cluster

echo "🔧 Installing Argo CD..."

# Create namespace
echo "📂 Creating argocd namespace..."
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -

# Install Argo CD
echo "🚀 Installing Argo CD..."
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for Argo CD to be ready
echo "⏳ Waiting for Argo CD pods to be ready..."
kubectl wait --for=condition=Ready pods --all -n argocd --timeout=600s

# Get initial admin password
echo "🔑 Retrieving initial admin password..."
ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)

# Port forward to access UI (run in background)
echo "🌐 Setting up port forwarding to Argo CD UI..."
echo "   Run this command in a separate terminal:"
echo "   kubectl port-forward svc/argocd-server -n argocd 8080:443"
echo ""

# Install Argo CD CLI (optional)
if ! command -v argocd &> /dev/null; then
    echo "📦 Installing Argo CD CLI..."
    if [[ "$OSTYPE" == "darwin"* ]]; then
        brew install argocd
    else
        # Linux
        curl -sSL -o /usr/local/bin/argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
        chmod +x /usr/local/bin/argocd
    fi
fi

echo ""
echo "✨ Argo CD installed successfully!"
echo ""
echo "📋 Access Information:"
echo "   URL: https://localhost:8080 (after port-forward)"
echo "   Username: admin"
echo "   Password: $ARGOCD_PASSWORD"
echo ""
echo "🔗 To access the UI:"
echo "   1. Run: kubectl port-forward svc/argocd-server -n argocd 8080:443"
echo "   2. Open: https://localhost:8080"
echo "   3. Login with admin / $ARGOCD_PASSWORD"
echo ""
echo "🔧 Change the password:"
echo "   argocd login localhost:8080"
echo "   argocd account update-password"
echo ""
echo "Next: Create an Application"
echo "   kubectl apply -f argo/application.yaml"
