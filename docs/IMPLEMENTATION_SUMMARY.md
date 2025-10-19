# Spot Nodes & Hibernation Implementation Summary

## Overview

This implementation adds cost optimization to your GKE Autopilot cluster through:

1. **Spot nodes** for all workloads (~70% cost reduction)
2. **Cluster hibernation** scripts (scale to 0 when not in use)

## Changes Made

### 1. Platform-Level Patches

**File**: `kubernetes/platform/overlays/prd/kustomization.yaml`

- Added reference to `spot-node-patch.yaml`

**File**: `kubernetes/platform/overlays/prd/spot-node-patch.yaml` (NEW)

- Patches for all Helm-based platform applications:
  - cert-manager (all components)
  - external-secrets (all components)
  - envoy-gateway
  - loki (all components)
  - mimir (all components)
  - prometheus (all components)
  - opentelemetry-collector

### 2. ArgoCD Patches

**File**: `kubernetes/argocd/overlays/prd/kustomization.yaml`

- Added reference to `spot-node-patch.yaml`

**File**: `kubernetes/argocd/overlays/prd/spot-node-patch.yaml` (NEW)

- Patches for all ArgoCD components:
  - argocd-applicationset-controller
  - argocd-dex-server
  - argocd-notifications-controller
  - argocd-redis
  - argocd-repo-server
  - argocd-server
  - argocd-application-controller (StatefulSet)

### 3. Platform Apps Patches

**external-dns**

- File: `kubernetes/platform-apps/external-dns/external-dns/overlays/prd/kustomization.yaml`
- Patch: Spot node selector for external-dns Deployment

**cnpg-operator**

- File: `kubernetes/platform-apps/cnpg-system/cnpg-operator/overlays/prd/kustomization.yaml`
- Patch: Spot node selector for cnpg-controller-manager Deployment

**cert-manager webhook**

- File: `kubernetes/platform-apps/cert-manager/cert-manager/overlays/prd/kustomization.yaml`
- Patch: Spot node selector for cert-manager-webhook-porkbun Deployment

**temporal**

- File: `kubernetes/platform-apps/temporal/base/temporal-values.yaml`
- Added: `nodeSelector` and `terminationGracePeriodSeconds` for all Temporal server components and web UI

- File: `kubernetes/platform-apps/temporal/base/postgresql-cluster.yaml`
- Added: `affinity.nodeAffinity` for CNPG PostgreSQL cluster to use spot nodes

**ktrlplane**

- File: `kubernetes/platform-apps/ktrlplane/ktrlplane/base/ktrlplane-helm.yaml`
- Added: `nodeSelector` and `terminationGracePeriodSeconds` for ktrlplane components

- File: `kubernetes/platform-apps/ktrlplane/ktrlplane/base/konnektr-graph-dbqr.yaml`
- Added: `nodeSelector` for API pods
- Added: `affinity.nodeAffinity` for CNPG database clusters created by DatabaseQueryResource

### 4. Scripts

**File**: `scripts/cluster-hibernate.ps1` (NEW)

- Suspends all ArgoCD Applications and ApplicationSets
- Scales all Deployments and StatefulSets to 0 (except kube-system)
- Waits for pods to terminate
- Supports `-DryRun` flag

**File**: `scripts/cluster-wakeup.ps1` (NEW)

- Restores automated sync policies on ArgoCD Applications and ApplicationSets
- Waits for ArgoCD to reconcile
- Monitors sync and health status
- Supports `-DryRun` flag

**File**: `scripts/validate-spot-config.ps1` (NEW)

- Validates all Deployments have spot node selectors/affinity
- Validates all StatefulSets have spot node selectors/affinity
- Validates all CNPG Clusters have spot node affinity
- Reports any missing configurations

### 5. Documentation

**File**: `docs/cost-optimization.md` (NEW)

- Comprehensive guide on cost optimization
- Cost comparison table
- How spot nodes work
- Hibernation/wakeup procedures
- Troubleshooting guide
- Best practices

**File**: `README.md` (UPDATED)

- Added cost optimization section
- Quick start commands
- Link to detailed guide
- Cost estimates

## Configuration Details

### Spot Node Selector

All Deployments and StatefulSets use:

```yaml
spec:
  template:
    spec:
      nodeSelector:
        cloud.google.com/gke-spot: "true"
      terminationGracePeriodSeconds: 15
```

### CNPG Cluster Affinity

All CNPG PostgreSQL clusters use:

```yaml
spec:
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
          - matchExpressions:
              - key: cloud.google.com/gke-spot
                operator: In
                values:
                  - "true"
```

## Deployment Instructions

### 1. Review Changes

```powershell
# Review all modified files
git status
git diff
```

### 2. Commit Changes

```powershell
git add .
git commit -m "feat: add spot nodes and hibernation for cost optimization"
git push
```

### 3. Monitor ArgoCD Sync

```powershell
# Wait for ArgoCD to sync changes
kubectl get applications -n argocd -w
```

### 4. Validate Configuration

```powershell
# After sync completes, validate all workloads
.\scripts\validate-spot-config.ps1
```

### 5. Test Hibernation

```powershell
# Test hibernation (dry run first)
.\scripts\cluster-hibernate.ps1 -DryRun

# Actual hibernation
.\scripts\cluster-hibernate.ps1

# Verify nodes scale to 0
kubectl get nodes -w
```

### 6. Test Wakeup

```powershell
# Wake up cluster
.\scripts\cluster-wakeup.ps1

# Monitor recovery
kubectl get applications -n argocd -w
kubectl get pods --all-namespaces -w
```

## Expected Behavior

### Immediate (after sync)

- All new pods scheduled on spot nodes
- GKE Autopilot provisions spot nodes automatically
- Existing pods on regular nodes (if any) continue running

### After Manual Pod Restart

- New pods land on spot nodes
- Old regular nodes eventually drained

### During Spot Preemption

- Pod receives SIGTERM
- 15 seconds grace period for cleanup
- Pod rescheduled on new spot node
- Database data persists (PersistentVolumes)

### During Hibernation

- All ArgoCD Applications suspended
- All user pods terminated
- Nodes scaled to 0 within ~5 minutes
- Cluster uses ~$0/month

### During Wakeup

- ArgoCD Applications restored
- Pods scheduled
- Spot nodes provisioned
- Full operation within 5-10 minutes

## Cost Impact

### Before (Autopilot without optimization)

- Control plane: $0 (free tier)
- Nodes (always-on, regular): ~$200-300/month
- **Total: ~$200-300/month**

### After (Spot nodes, always-on)

- Control plane: $0 (free tier)
- Nodes (always-on, spot): ~$60-100/month
- **Total: ~$60-100/month** (70% savings)

### After (Spot nodes + hibernation, 8hrs/day)

- Control plane: $0 (free tier)
- Nodes (running 8hrs/day): ~$20-40/month
- Storage (always): ~$1/month
- **Total: ~$20-40/month** (85% savings)

### After (Hibernated)

- Control plane: $0 (free tier)
- Nodes: $0
- Storage: ~$1/month
- **Total: ~$1/month** (99.5% savings)

## Files Added

```
docs/
  cost-optimization.md          # Comprehensive cost optimization guide

scripts/
  cluster-hibernate.ps1         # Hibernate cluster script
  cluster-wakeup.ps1            # Wake up cluster script
  validate-spot-config.ps1      # Validation script

kubernetes/
  platform/overlays/prd/
    spot-node-patch.yaml        # Helm chart patches for spot nodes

  argocd/overlays/prd/
    spot-node-patch.yaml        # ArgoCD component patches for spot nodes
```

## Files Modified

```
README.md                       # Added cost optimization section

kubernetes/platform/overlays/prd/
  kustomization.yaml            # Added spot-node-patch.yaml reference

kubernetes/argocd/overlays/prd/
  kustomization.yaml            # Added spot-node-patch.yaml reference

kubernetes/platform-apps/external-dns/external-dns/overlays/prd/
  kustomization.yaml            # Added spot node patch

kubernetes/platform-apps/cnpg-system/cnpg-operator/overlays/prd/
  kustomization.yaml            # Added spot node patch

kubernetes/platform-apps/cert-manager/cert-manager/overlays/prd/
  kustomization.yaml            # Added spot node patch

kubernetes/platform-apps/temporal/base/
  temporal-values.yaml          # Added nodeSelector
  postgresql-cluster.yaml       # Added affinity

kubernetes/platform-apps/ktrlplane/ktrlplane/base/
  ktrlplane-helm.yaml           # Added nodeSelector
  konnektr-graph-dbqr.yaml      # Added nodeSelector and affinity
```

## Testing Checklist

- [ ] Changes committed and pushed
- [ ] ArgoCD synced all applications
- [ ] All pods running on spot nodes (validate-spot-config.ps1)
- [ ] Hibernation tested (dry run)
- [ ] Hibernation tested (actual)
- [ ] Nodes scaled to 0 confirmed
- [ ] Wakeup tested
- [ ] All applications healthy after wakeup
- [ ] Spot preemption behavior tested (optional)

## Rollback Plan

If issues occur:

```powershell
# Revert git changes
git revert <commit-hash>
git push

# ArgoCD will auto-sync and restore previous state
```

Or manually remove spot node selectors:

```powershell
# Remove nodeSelector from a specific deployment
kubectl patch deployment <name> -n <namespace> --type=json -p='[{"op": "remove", "path": "/spec/template/spec/nodeSelector/cloud.google.com~1gke-spot"}]'
```

## Support

For issues or questions:

1. Check `docs/cost-optimization.md` troubleshooting section
2. Validate configuration: `.\scripts\validate-spot-config.ps1`
3. Check ArgoCD UI for sync status
4. Review pod events: `kubectl describe pod <pod-name> -n <namespace>`
