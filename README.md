# Konnektr Infra Repository

This repository manages all cloud infrastructure and Kubernetes platform manifests for the Konnektr startup.

## 💰 Cost Optimization

This cluster is configured for **maximum cost savings** using:
- ✅ **Spot nodes only** (~70% cheaper than regular nodes)
- ✅ **Cluster hibernation** (scale to 0 when not in use)
- ✅ **Free Autopilot control plane** (no control plane costs)

**Quick start:**
```powershell
# Hibernate cluster (scale to 0)
.\scripts\cluster-hibernate.ps1

# Wake up cluster
.\scripts\cluster-wakeup.ps1
```

**📖 See [Cost Optimization Guide](docs/cost-optimization.md) for details**

**Typical costs:**
- Active development (8hrs/day): ~$20-40/month
- Hibernated: ~$0/month
- Always-on spot nodes: ~$60-100/month

## Structure

- `terraform/` — Infrastructure as code for Google Cloud (GKE, networking, etc.)
- `kubernetes/` — Manifests for platform, ArgoCD, and applications (GitOps)

## Getting Started

### Prerequisites

- [Terraform](https://www.terraform.io/downloads.html)
- [Google Cloud SDK](https://cloud.google.com/sdk/docs/install)
- Access to a Google Cloud project

### Terraform Setup

1. Authenticate with Google Cloud:
   ```sh
   gcloud auth application-default login
   ```
2. Update `terraform/backend.tf` with your GCS bucket name for remote state.
3. Set required variables in `terraform/envs/prod/` and `terraform/envs/dev/`.
4. Initialize and apply:
   ```sh
   terraform init
   terraform plan -var-file=envs/prod/terraform.tfvars
   terraform apply -var-file=envs/prod/terraform.tfvars
   ```

### Kubernetes & GitOps

- Manifests are organized with `base` and `overlays` for each component.
- Use [Kustomize](https://kustomize.io/) for overlays.
- ArgoCD ApplicationSet is defined in `kubernetes/platform/application-set.yaml`.
- To bootstrap ArgoCD, apply manifests in `kubernetes/argocd/overlays/prd`.

## Best Practices

- Use modules for reusable Terraform components.
- Store state remotely in a dedicated GCS bucket.
- Use least privilege service accounts for Terraform.
- Parameterize namespaces in overlays to avoid collisions.
- Document all resources and variables.

## Next Steps

- Add platform and app manifests in `platform-apps/` and `apps/`.
- Expand overlays for dev environments as needed.
