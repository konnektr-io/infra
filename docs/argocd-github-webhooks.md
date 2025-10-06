# ArgoCD GitHub Webhooks Setup Guide

This guide shows how to configure GitHub webhooks to trigger ArgoCD synchronization instantly instead of relying on polling.

## Benefits of Webhooks vs Polling

- ⚡ **Instant deployments**: Changes trigger sync immediately (not every hour)
- 💰 **Cost reduction**: Eliminates constant GitHub API polling
- 🔋 **Better performance**: Reduces ArgoCD controller load
- 🎯 **Event-driven**: Only syncs when actual changes occur

## Prerequisites

1. ArgoCD deployed with external ingress (`argocd.konnektr.io`)
2. External Secrets configured for secret management
3. GitHub repositories with push access

## Implementation Overview

### Components Added

1. **Webhook Secret**: Stored in Google Secret Manager, retrieved via external-secrets
2. **HTTPRoute Update**: Exposes `/api/webhook` endpoint
3. **ArgoCD ConfigMap**: Enables webhook validation with secret
4. **GitHub Webhook**: Configured to send push events to ArgoCD

## Step 1: Store Webhook Secret in Google Secret Manager

Generate a secure webhook secret and store it:

```bash
# Generate a secure random secret (32 bytes)
WEBHOOK_SECRET=$(openssl rand -hex 32)
echo $WEBHOOK_SECRET

# Store in Google Secret Manager
echo -n "$WEBHOOK_SECRET" | gcloud secrets create argocd-github-webhook-secret --data-file=-

# Or update existing secret
echo -n "$WEBHOOK_SECRET" | gcloud secrets versions add argocd-github-webhook-secret --data-file=-
```

**Save this secret** - you'll need it for GitHub webhook configuration!

## Step 2: Deploy ArgoCD Changes

Apply the updated ArgoCD configuration:

```bash
# Deploy ArgoCD with webhook support
kubectl apply -k kubernetes/argocd/overlays/prd/

# Verify external secret is working
kubectl get externalsecret -n argocd
kubectl describe externalsecret argocd-github-webhook-secret -n argocd

# Check that webhook secret is in argocd-secret
kubectl get secret argocd-secret -n argocd -o yaml | grep webhook
```

## Step 3: Configure GitHub Webhooks

### For Infrastructure Repository (konnektr-io/infra)

1. Go to GitHub: `https://github.com/konnektr-io/infra/settings/hooks`
2. Click **"Add webhook"**
3. Configure:
   - **Payload URL**: `https://argocd.konnektr.io/api/webhook`
   - **Content type**: `application/json`
   - **Secret**: `[paste the webhook secret from Step 1]`
   - **Which events**: Select "Just the push event"
   - **Active**: ✅ Checked

### For Application Repositories

Repeat the same process for each application repository that ArgoCD monitors:

```bash
# Example URLs for your app repositories:
# https://github.com/konnektr-io/api/settings/hooks
# https://github.com/konnektr-io/web/settings/hooks
# https://github.com/konnektr-io/worker/settings/hooks
```

## Step 4: Test Webhook Integration

### Test 1: Infrastructure Changes

```bash
# Make a change to this infra repository
echo "# Webhook test $(date)" >> README.md
git add README.md
git commit -m "test: webhook integration"
git push origin main

# Check ArgoCD UI - should sync immediately
# Or check via CLI:
argocd app get platform --server argocd.konnektr.io
```

### Test 2: Application Changes

```bash
# Make a change to an application repository
# Push the change
# ArgoCD should detect and sync the change immediately
```

## Step 5: Optimize Polling Settings (Optional)

Since webhooks handle most updates, you can further reduce polling:

Update `argocd-cm.yaml`:

```yaml
timeout.reconciliation: 24h # Reduce from 1h to 24h
timeout.reconciliation.jitter: 1h # Reduce jitter
```

Or disable polling entirely for webhook-enabled repositories:

```yaml
# In your Application specs, add:
spec:
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    # Disable automated sync for webhook-driven repos
    # syncOptions:
    #   - RespectIgnoreDifferences=true
```

## Troubleshooting

### Webhook Not Triggering

1. **Check GitHub webhook deliveries**:

   - Go to repo settings → webhooks → your webhook
   - Check "Recent Deliveries" tab for errors

2. **Verify webhook endpoint is accessible**:

   ```bash
   # Test from outside your cluster
   curl -X POST https://argocd.konnektr.io/api/webhook \
     -H "Content-Type: application/json" \
     -d '{"test": "webhook"}'

   # Should return 200 OK (even without valid signature)
   ```

3. **Check ArgoCD logs**:
   ```bash
   kubectl logs -n argocd -l app.kubernetes.io/name=argocd-server -f
   # Look for webhook-related messages
   ```

### Secret Issues

1. **Check external secret status**:

   ```bash
   kubectl describe externalsecret argocd-github-webhook-secret -n argocd
   ```

2. **Verify secret contents**:
   ```bash
   kubectl get secret argocd-secret -n argocd -o jsonpath='{.data.webhook\.github\.secret}' | base64 -d
   ```

### Application Not Syncing

1. **Check if webhook matched repository**:

   - ArgoCD matches webhooks to repositories by URL
   - Ensure your Application's `spec.source.repoURL` matches the webhook source

2. **Manual sync test**:
   ```bash
   argocd app sync your-app-name --server argocd.konnektr.io
   ```

## Security Considerations

- ✅ **Secret validation**: Webhooks are validated using HMAC-SHA256
- ✅ **TLS encryption**: All webhook traffic uses HTTPS
- ✅ **Access control**: Only push events from configured repositories trigger syncs
- ✅ **Secret rotation**: Webhook secret can be rotated via Google Secret Manager

## GitHub Webhook Payload Example

When you push to a repository, GitHub sends a payload like:

```json
{
  "ref": "refs/heads/main",
  "repository": {
    "clone_url": "https://github.com/konnektr-io/infra.git",
    "ssh_url": "git@github.com:konnektr-io/infra.git"
  },
  "commits": [
    {
      "id": "abc123...",
      "message": "feat: add new feature",
      "author": {...}
    }
  ]
}
```

ArgoCD processes this and triggers sync for matching Applications.

## Monitoring Webhook Activity

### ArgoCD UI

- Go to Applications → your app → Events
- Look for "ResourceUpdated" events triggered by webhooks

### Metrics (if monitoring is enabled)

```bash
# Webhook requests received
argocd_webhook_requests_total

# Webhook processing duration
argocd_webhook_processing_duration_seconds
```

## Migration from Polling

If you had very frequent polling before:

1. Deploy webhook configuration
2. Test webhook functionality
3. Gradually increase polling intervals
4. Monitor for any missed updates
5. Consider disabling polling for webhook-enabled repos
