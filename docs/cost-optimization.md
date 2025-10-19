# Cost Optimization Guide

This guide explains how to minimize costs for your GKE cluster using spot nodes and cluster hibernation.

## 💰 Cost Savings Summary

| Scenario                         | Monthly Cost | Savings  |
| -------------------------------- | ------------ | -------- |
| Always-on (regular nodes)        | ~$200-300    | Baseline |
| Always-on (spot nodes)           | ~$60-100     | ~70%     |
| Hibernated (scaled to 0)         | ~$0          | ~100%    |
| **Typical dev usage (8hrs/day)** | **~$20-40**  | **~85%** |

> **Note:** With the free Autopilot control plane tier, you only pay for running nodes. When hibernated, costs drop to near $0 (only for storage ~$1/month).

## 🎯 Spot Nodes Configuration

All workloads in this cluster are configured to run exclusively on **spot nodes**, providing ~70% cost savings compared to regular nodes.

### How It Works

1. **Node Selector Applied**: All pods have `cloud.google.com/gke-spot: "true"` node selector
2. **GKE Autopilot Provisioning**: GKE automatically provisions spot nodes when pods are scheduled
3. **Graceful Termination**: Pods have 15s `terminationGracePeriodSeconds` to handle spot preemptions
4. **Auto-Replacement**: If a spot node is preempted, GKE provisions a new one automatically

### What's Configured

✅ **ArgoCD** - All components (server, repo-server, application-controller, etc.)  
✅ **Platform Operators** - cert-manager, external-secrets, CNPG operator, external-dns  
✅ **Observability** - Loki, Mimir, Prometheus, OpenTelemetry Collector  
✅ **Gateways** - Envoy Gateway  
✅ **Applications** - Temporal, ktrlplane, databases (CNPG)

### Spot Node Behavior

**Preemption Warning**: Spot nodes receive a 30-second warning before termination  
**Grace Period**: Pods configured with 15s `terminationGracePeriodSeconds`  
**Data Safety**: Persistent volumes (databases) survive spot node terminations  
**Availability**: Suitable for dev/staging; for production, use a mix of spot + regular nodes

## 🌙 Cluster Hibernation

Save maximum costs by scaling everything to 0 when not actively developing.

### Quick Start

**Hibernate (shut down):**

```powershell
.\scripts\cluster-hibernate.ps1
```

**Wake up (start):**

```powershell
.\scripts\cluster-wakeup.ps1
```

### What Happens During Hibernation

1. **ArgoCD suspended** - All Applications/ApplicationSets automated sync disabled
2. **Workloads scaled to 0** - All Deployments/StatefulSets scaled to 0 replicas
3. **Pods terminated** - All user pods gracefully shut down
4. **Nodes scaled to 0** - GKE Autopilot automatically removes all nodes (within ~5 minutes)
5. **Cost drops to ~$0** - Only storage costs remain

### What Happens During Wakeup

1. **ArgoCD restored** - Automated sync re-enabled on all Applications/ApplicationSets
2. **ArgoCD reconciles** - Automatically restores all workloads from git state
3. **Nodes provisioned** - GKE Autopilot provisions spot nodes as pods are scheduled
4. **Services start** - Applications come online in dependency order
5. **Full operation** - Cluster fully operational (typically 5-10 minutes)

### Hibernate Script Options

```powershell
# Dry run (see what would happen without making changes)
.\scripts\cluster-hibernate.ps1 -DryRun

# Normal hibernation
.\scripts\cluster-hibernate.ps1
```

### Wakeup Script Options

```powershell
# Dry run (see what would happen without making changes)
.\scripts\cluster-wakeup.ps1 -DryRun

# Normal wakeup
.\scripts\cluster-wakeup.ps1
```

## 📊 Monitoring Status

### Check if cluster is hibernated

```powershell
# Check running pods
kubectl get pods --all-namespaces

# Check ArgoCD Applications status
kubectl get applications -n argocd

# Check node count
kubectl get nodes
```

### Monitor wakeup progress

```powershell
# Watch ArgoCD sync status
kubectl get applications -n argocd -w

# Watch pods starting
kubectl get pods --all-namespaces -w

# Check nodes being provisioned
kubectl get nodes -w
```

## 🔧 Troubleshooting

### Hibernation Issues

**Problem**: Pods not terminating  
**Solution**: Force delete stuck pods:

```powershell
kubectl delete pod <pod-name> -n <namespace> --force --grace-period=0
```

**Problem**: ArgoCD keeps recreating pods  
**Solution**: Ensure Applications are suspended before scaling:

```powershell
kubectl get applications -n argocd -o json | jq '.items[] | select(.spec.syncPolicy.automated != null) | .metadata.name'
```

### Wakeup Issues

**Problem**: Pods stuck in Pending  
**Solution**: Check node provisioning:

```powershell
kubectl get nodes
kubectl describe pod <pod-name> -n <namespace>
```

**Problem**: Applications OutOfSync  
**Solution**: Manually sync in ArgoCD:

```powershell
kubectl patch application <app-name> -n argocd -p '{"operation":{"initiatedBy":{"username":"admin"},"sync":{"syncStrategy":{"hook":{}}}}}' --type=merge
```

**Problem**: Spot nodes not provisioning  
**Solution**: Check for Autopilot quotas:

```powershell
gcloud container clusters describe konnektr-gke --region europe-west1 --format="yaml(autoscaling)"
```

## 🎨 Best Practices

### Daily Development

```powershell
# Morning: Wake up cluster
.\scripts\cluster-wakeup.ps1

# ... develop during the day ...

# Evening: Hibernate cluster
.\scripts\cluster-hibernate.ps1
```

### Weekend/Vacation

Keep cluster hibernated - costs will be ~$0/month.

### Active Development Session

Keep cluster running if actively developing (costs ~$60-100/month).

### Production Deployment

For production:

1. Create separate `dev` overlay with same spot configuration
2. Create `prd` overlay with mixed spot + regular nodes for high availability
3. Adjust `instances` count for databases to 3+ replicas

## 📝 Technical Details

### Spot Node Selector Patches

Patches are applied via Kustomize overlays in `kubernetes/platform/overlays/prd/`:

- **Kustomize-based apps**: Strategic merge patches in overlay kustomizations
- **Helm-based apps**: `valuesObject` overrides in ArgoCD Application specs
- **CNPG databases**: `affinity.nodeAffinity` for node selection

### Files Modified

```
kubernetes/
├── platform/overlays/prd/
│   ├── kustomization.yaml          # Added spot-node-patch.yaml
│   └── spot-node-patch.yaml        # Helm chart patches
├── argocd/overlays/prd/
│   ├── kustomization.yaml          # Added spot-node-patch.yaml
│   └── spot-node-patch.yaml        # ArgoCD component patches
├── platform-apps/
│   ├── external-dns/.../prd/kustomization.yaml  # Spot patch
│   ├── cnpg-system/.../prd/kustomization.yaml   # Spot patch
│   ├── cert-manager/.../prd/kustomization.yaml  # Spot patch
│   ├── temporal/base/
│   │   ├── temporal-values.yaml    # nodeSelector added
│   │   └── postgresql-cluster.yaml # affinity added
│   └── ktrlplane/.../base/
│       ├── ktrlplane-helm.yaml     # nodeSelector added
│       └── konnektr-graph-dbqr.yaml # nodeSelector/affinity added
```

### Autopilot Behavior

GKE Autopilot automatically:

- Provisions spot nodes when pods with spot selector are scheduled
- Scales nodes to 0 when no pods are running (after ~5 minutes)
- Handles spot preemptions by rescheduling pods
- Manages resource limits and quotas

## 🚀 Next Steps

1. **Deploy the changes**: Commit and push to trigger ArgoCD sync
2. **Test hibernation**: Run hibernate script and verify nodes scale to 0
3. **Test wakeup**: Run wakeup script and verify cluster comes back online
4. **Monitor costs**: Check GCP billing to confirm savings
5. **Automate**: Consider GitHub Actions to hibernate on schedule (e.g., nights/weekends)

## ⚠️ Important Notes

- **Spot preemptions**: Expect occasional pod restarts (GKE auto-recovers)
- **State preservation**: All configuration is in git; databases use persistent storage
- **Wakeup time**: Allow 5-10 minutes for full cluster restoration
- **Free tier**: One free Autopilot cluster per billing account (check your quota)
- **Development only**: This configuration is optimized for dev/test environments
