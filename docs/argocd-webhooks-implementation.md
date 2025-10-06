# ArgoCD GitHub Webhooks - Implementation Summary

## What Was Implemented

### ✅ **ArgoCD Webhook Configuration**

- **File**: `kubernetes/argocd/argocd-cm.yaml`
- **Added**: `webhook.github.secret: $webhook.github.secret`
- **Result**: ArgoCD now validates GitHub webhook signatures

### ✅ **External Secret for Webhook**

- **File**: `kubernetes/argocd/github-webhook-external-secret.yaml`
- **Purpose**: Fetches webhook secret from Google Secret Manager
- **Merges**: Into existing `argocd-secret` alongside Auth0 credentials

### ✅ **HTTPRoute Configuration**

- **File**: `kubernetes/argocd/argocd-server-httproute.yaml`
- **Added**: `/api/webhook` endpoint routing
- **Accessible**: `https://argocd.konnektr.io/api/webhook`

### ✅ **Optimized Polling**

- **Changed**: Polling from 1h to 24h (since webhooks handle real-time updates)
- **Reduced**: Jitter from 5m to 1h
- **Result**: 96% reduction in GitHub API calls

### ✅ **Setup Scripts**

- **Bash**: `scripts/setup-github-webhook-secret.sh`
- **PowerShell**: `scripts/setup-github-webhook-secret.ps1`
- **Purpose**: Generate and store webhook secret securely

## Deployment Steps

### 1. **Generate and Store Webhook Secret**

```bash
# Linux/macOS
chmod +x scripts/setup-github-webhook-secret.sh
./scripts/setup-github-webhook-secret.sh

# Windows PowerShell
.\scripts\setup-github-webhook-secret.ps1
```

### 2. **Deploy ArgoCD Configuration**

```bash
kubectl apply -k kubernetes/argocd/overlays/prd/
```

### 3. **Configure GitHub Webhooks**

For each repository (infra, API, web, etc.):

1. Go to repo Settings → Webhooks → Add webhook
2. **URL**: `https://argocd.konnektr.io/api/webhook`
3. **Secret**: [Use generated secret from Step 1]
4. **Events**: "Just the push event"
5. **Content-Type**: `application/json`

### 4. **Test Integration**

```bash
# Make a commit to trigger webhook
echo "# Webhook test" >> README.md
git add README.md && git commit -m "test: webhook" && git push

# Check ArgoCD for immediate sync
```

## Expected Behavior

### ⚡ **Before (Polling Only)**

- Changes detected every 1-24 hours
- Constant GitHub API polling
- Higher resource usage
- Delayed deployments

### 🚀 **After (Webhooks + Reduced Polling)**

- Changes detected instantly (within seconds)
- 96% fewer GitHub API calls
- Lower resource usage
- Immediate deployments

## Security Features

- ✅ **HMAC-SHA256 signature validation**
- ✅ **Secret stored in Google Secret Manager**
- ✅ **TLS encryption for all webhook traffic**
- ✅ **External secrets automatic refresh (15m)**

## Monitoring

### Check Webhook Status

```bash
# Verify external secret
kubectl get externalsecret argocd-github-webhook-secret -n argocd

# Check ArgoCD logs for webhook events
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-server -f | grep webhook

# Test endpoint accessibility
curl -X POST https://argocd.konnektr.io/api/webhook
```

### GitHub Webhook Deliveries

- Go to GitHub repo → Settings → Webhooks → [your webhook]
- Check "Recent Deliveries" for success/failure status
- Should see 200 OK responses for successful deliveries

## Troubleshooting

### Common Issues

1. **404 on webhook endpoint**: Check HTTPRoute deployment
2. **401/403 errors**: Verify webhook secret matches
3. **No sync triggered**: Check repository URL matches ArgoCD Application

### Debug Commands

```bash
# Check all ArgoCD resources
kubectl get all -n argocd

# Verify secret contents
kubectl get secret argocd-secret -n argocd -o yaml

# Test external connectivity
nslookup argocd.konnektr.io
```

## Performance Impact

### Resource Savings

- **GitHub API calls**: Reduced by ~96%
- **ArgoCD controller CPU**: Reduced polling overhead
- **Network traffic**: Fewer outbound requests
- **Latency**: Near-instant sync vs 1-24h delay

### Cost Savings

- **GitHub API limits**: Significant reduction in rate limit usage
- **Compute costs**: Lower CPU usage from reduced polling
- **Bandwidth**: Fewer API requests

## Files Modified/Created

```
kubernetes/argocd/
├── argocd-cm.yaml                     # ✏️  Modified: Added webhook.github.secret
├── argocd-server-httproute.yaml       # ✏️  Modified: Added /api/webhook route
├── github-webhook-external-secret.yaml # ➕ New: External secret for webhook
├── kustomization.yaml                 # ✏️  Modified: Added webhook external secret

scripts/
├── setup-github-webhook-secret.sh     # ➕ New: Bash setup script
└── setup-github-webhook-secret.ps1    # ➕ New: PowerShell setup script

docs/
└── argocd-github-webhooks.md          # ➕ New: Complete setup guide
```

This implementation provides a production-ready GitHub webhook integration for ArgoCD with proper security, monitoring, and automation.
