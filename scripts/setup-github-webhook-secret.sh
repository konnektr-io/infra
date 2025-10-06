#!/bin/bash
# GitHub Webhook Secret Setup for ArgoCD

set -e

echo "🔐 Setting up GitHub webhook secret for ArgoCD..."
echo ""

# Check if gcloud is available
if ! command -v gcloud &> /dev/null; then
    echo "❌ gcloud CLI is not installed. Please install it first."
    exit 1
fi

# Check if openssl is available
if ! command -v openssl &> /dev/null; then
    echo "❌ openssl is not available. Please install it first."
    exit 1
fi

# Generate secure webhook secret
echo "🔑 Generating secure webhook secret..."
WEBHOOK_SECRET=$(openssl rand -hex 32)

echo "✅ Generated webhook secret: $WEBHOOK_SECRET"
echo ""

# Store in Google Secret Manager
echo "☁️  Storing secret in Google Secret Manager..."
echo -n "$WEBHOOK_SECRET" | gcloud secrets create argocd-github-webhook-secret --data-file=- 2>/dev/null || {
    echo "Secret already exists, updating version..."
    echo -n "$WEBHOOK_SECRET" | gcloud secrets versions add argocd-github-webhook-secret --data-file=-
}

echo "✅ Secret stored in Google Secret Manager as 'argocd-github-webhook-secret'"
echo ""

echo "📋 Next steps:"
echo "1. Deploy ArgoCD configuration:"
echo "   kubectl apply -k kubernetes/argocd/overlays/prd/"
echo ""
echo "2. Configure GitHub webhooks with this secret:"
echo "   Secret: $WEBHOOK_SECRET"
echo "   URL: https://argocd.konnektr.io/api/webhook"
echo ""
echo "3. Test webhook delivery in GitHub repository settings"
echo ""

# Save secret to temporary file for easy copy-paste
echo "$WEBHOOK_SECRET" > /tmp/argocd-webhook-secret.txt
echo "💾 Secret also saved to: /tmp/argocd-webhook-secret.txt"
echo "   (This file will be automatically deleted after 1 hour)"

# Schedule cleanup
(sleep 3600 && rm -f /tmp/argocd-webhook-secret.txt) &