# Copilot Instructions for `konnektr-io/infra`

## Purpose

This repository manages all cloud infrastructure and Kubernetes platform manifests for the Konnektr startup. Infrastructure is provisioned using Terraform (Google Cloud, GKE, networking, storage, etc.). Kubernetes manifests are organized for GitOps deployment via ArgoCD.

## Directory Structure

```
infra/
├── terraform/
│   ├── modules/                # Reusable Terraform modules (network, GKE, etc.)
│   ├── envs/
│   │   ├── prod/               # Production environment configs
│   │   └── dev/                # Development environment configs (future: separate cluster)
│   ├── main.tf                 # Entry point for Terraform
│   ├── gke.tf                  # GKE cluster resources
│   ├── network.tf              # Networking resources
│   ├── versions.tf             # Provider and module versions
│   ├── variables.tf            # Shared variables
│   ├── outputs.tf              # Shared outputs
│   └── backend.tf              # Remote state config (Google Cloud Storage)
├── kubernetes/
│   ├── argocd/
│   │   ├── base/
│   │   └── overlays/
│   │       └── prd/
│   ├── platform/
│   │   ├── base/
│   │   └── overlays/
│   │       └── prd/
│   │   └── platform-apps.yaml  # ArgoCD ApplicationSet config (single file)
│   │   └── apps.yaml           # ArgoCD ApplicationSet config (single file)
│   ├── platform-apps/
│   │   ├── <platform-app>/
│   │   │   ├── base/
│   │   │   └── overlays/
│   │   │       └── prd/
│   │   └── ...                 # More platform apps/components as needed
│   ├── apps/
│   │   ├── <app-name>/
│   │   │   ├── base/
│   │   │   └── overlays/
│   │   │       └── prd/
│   │   └── ...                 # More apps/components as needed
└── README.md
```

## Terraform Best Practices

- Use modules for reusable infrastructure components (network, GKE, IAM, etc.).
- Store state remotely in a dedicated Google Cloud Storage bucket.
- Use separate variable files for dev/prod (even if sharing a cluster initially).
- Use service accounts with least privilege for Terraform operations.
- Prepare for CI/CD (GitHub Actions) by using environment variables and secrets for credentials.
- Document all resources and variables.

## Kubernetes Manifests & GitOps

- Organize manifests with `base` and `overlays` folders for each component (argocd, platform, apps).
- Use ArgoCD ApplicationSets to manage multiple applications/components.
- Avoid namespace collisions by parameterizing namespaces in overlays.
- Only create `prd` overlays for now, but structure for easy addition of `dev` overlays.
- Use Kustomize for overlays and customization.
- Document manifest structure and deployment flow.

## Getting Started

- Add a comprehensive `README.md` with setup instructions for local Terraform usage, state backend configuration, and GitOps workflow.
- Include instructions for authenticating Terraform locally (gcloud CLI, service account keys).
- Document how to bootstrap ArgoCD and deploy manifests via GitOps.

## Next Steps

- Review these instructions.
- Once approved, proceed to scaffold the directory structure and add initial boilerplate files (Terraform, Kubernetes, README).
