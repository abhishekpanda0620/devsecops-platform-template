#!/bin/bash
# Bootstrap Secrets Script
# Helper to create necessary Kubernetes secrets for the platform

set -e

echo "🔐 Bootstrap Secrets for DevSecOps Platform"
echo "==========================================="

# Check kubectl connection
if ! kubectl cluster-info >/dev/null 2>&1; then
    echo "❌ Error: kubectl is not connected to a cluster."
    echo "   Please update your kubeconfig using: aws eks update-kubeconfig --name <cluster-name>"
    exit 1
fi

echo "✅ Connected to Kubernetes cluster"
echo ""

# 1. ArgoCD Notifications Secret (Slack)
echo "--- 1. ArgoCD Notifications (Slack) ---"

if [ -n "$SLACK_WEBHOOK_URL" ]; then
    echo "   🔑 SLACK_WEBHOOK_URL found in environment."
else
    read -s -p "Enter Slack Webhook URL (https://hooks.slack.com/...) [Press Enter to skip]: " SLACK_WEBHOOK_URL
    echo ""
fi

if [ -n "$SLACK_WEBHOOK_URL" ]; then
    kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
    
    # Create the secret
    kubectl create secret generic argocd-notifications-secret \
      -n argocd \
      --from-literal=slack-token="$SLACK_WEBHOOK_URL" \
      --dry-run=client -o yaml | kubectl apply -f -
      
    echo "   ✅ Created 'argocd-notifications-secret' in 'argocd' namespace"

    # Create secret for Alertmanager (observability)
    kubectl create namespace observability --dry-run=client -o yaml | kubectl apply -f -
    
    kubectl create secret generic alertmanager-slack-creds \
      -n observability \
      --from-literal=api_url="$SLACK_WEBHOOK_URL" \
      --dry-run=client -o yaml | kubectl apply -f -
      
    echo "   ✅ Created 'alertmanager-slack-creds' in 'observability' namespace"
else
    echo "   ⚠️ Skipped Slack Webhook"
fi
echo ""

# 2. Container Registry Credentials (Optional)
echo "--- 2. Container Registry Credentials (GHCR/DockerHub) ---"
read -p "Do you want to create a registry pull secret? (y/n): " CREATE_REGISTRY
if [[ "$CREATE_REGISTRY" =~ ^[Yy]$ ]]; then
    read -p "Registry Server (e.g., ghcr.io): " REG_SERVER
    read -p "Username: " REG_USER
    read -s -p "Password/Token: " REG_PASS
    echo ""
    read -p "Email: " REG_EMAIL
    
    # Create in multiple namespaces
    for ns in dev staging prod; do
        kubectl create namespace $ns --dry-run=client -o yaml | kubectl apply -f -
        
        kubectl create secret docker-registry regcred \
          --docker-server="$REG_SERVER" \
          --docker-username="$REG_USER" \
          --docker-password="$REG_PASS" \
          --docker-email="$REG_EMAIL" \
          -n $ns \
          --dry-run=client -o yaml | kubectl apply -f -
          
        echo "   ✅ Created 'regcred' in '$ns' namespace"
    done
else
    echo "   ⚠️ Skipped Registry Credentials"
fi

echo ""
echo "🎉 Secret bootstrapping complete!"
