# 💰 Cost Optimization Quick Reference

## 🚀 Quick Commands

```powershell
# Hibernate cluster (save money)
.\scripts\cluster-hibernate.ps1

# Wake up cluster (resume work)
.\scripts\cluster-wakeup.ps1

# Validate configuration
.\scripts\validate-spot-config.ps1

# Check status
kubectl get applications -n argocd
kubectl get pods --all-namespaces
kubectl get nodes
```

## 💵 Cost Estimates

| Usage Pattern          | Cost/Month | Savings  |
| ---------------------- | ---------- | -------- |
| Hibernated             | ~$0        | 99.5%    |
| 8hrs/day (typical dev) | ~$20-40    | 85%      |
| Always-on (spot)       | ~$60-100   | 70%      |
| Always-on (regular)    | ~$200-300  | Baseline |

## ⏱️ Timing

- **Hibernation**: ~2-5 minutes
- **Wakeup**: ~5-10 minutes
- **Spot preemption recovery**: ~1-3 minutes

## ✅ What's Running on Spot Nodes

- ✅ ArgoCD (all components)
- ✅ cert-manager, external-secrets, CNPG operator
- ✅ external-dns, Envoy Gateway
- ✅ Loki, Mimir, Prometheus, OpenTelemetry
- ✅ Temporal (all components + database)
- ✅ ktrlplane (app + databases)

## 🔍 Quick Checks

**Is cluster hibernated?**

```powershell
kubectl get pods --all-namespaces | Select-String -Pattern "Running"
# Should be empty (except kube-system)
```

**Are nodes spot?**

```powershell
kubectl get nodes -o json | ConvertFrom-Json | %{ $_.items.metadata.labels.'cloud.google.com/gke-spot' }
# Should all be "true"
```

**ArgoCD sync status:**

```powershell
kubectl get applications -n argocd -o wide
```

## 📚 Documentation

- **Full guide**: `docs/cost-optimization.md`
- **Implementation**: `docs/IMPLEMENTATION_SUMMARY.md`
- **Main README**: `README.md`

## 🆘 Troubleshooting

**Pods stuck in Pending:**

```powershell
kubectl describe pod <pod-name> -n <namespace>
# Check events for scheduling issues
```

**Applications OutOfSync:**

```powershell
# Force sync in ArgoCD
kubectl get applications -n argocd
# Then sync via ArgoCD UI or CLI
```

**Hibernation not working:**

```powershell
# Check if Applications are suspended
kubectl get applications -n argocd -o json | jq '.items[] | {name: .metadata.name, automated: .spec.syncPolicy.automated}'
```

## 💡 Best Practices

- 🌙 Hibernate overnight & weekends
- ☀️ Wake up when starting work
- 🔄 Keep hibernated during vacations
- 📊 Monitor GCP billing for savings
- ✅ Run validate-spot-config after changes
