# ArgoCD Auth0 Integration - Design Decisions

## Why Auth0 Application (not API)?

ArgoCD uses **OIDC (OpenID Connect)** for authentication, which is built on top of OAuth 2.0. OIDC primarily uses **ID tokens** to convey user identity information, which is exactly what ArgoCD needs.

- **Regular Web Application**: Provides ID tokens with user identity claims
- **API**: Designed for access tokens to authorize API calls (not what ArgoCD needs)

## Why Separate Service Account for External Secrets?

### Security Isolation
- **Principle of Least Privilege**: Each service gets only the permissions it needs
- **GKE Node SA**: Has broad node-level permissions (container.nodeServiceAccount, storage.objectViewer)
- **External Secrets SA**: Only has secretmanager.secretAccessor

### Operational Benefits
- **Independent Lifecycle**: Can manage external-secrets permissions without affecting GKE nodes
- **Audit Trail**: Clear separation of who accessed which secrets
- **Rotation**: Can rotate external-secrets credentials without disrupting cluster nodes

## Auth0 Groups Scoped to ArgoCD Only

### The Problem
Adding groups to ID tokens globally affects **all applications** using the same Auth0 tenant, which could:
- Expose internal role information to other applications
- Create security concerns
- Cause JWT size issues

### The Solution
Use Auth0 Actions with **client_id** checking:

```javascript
if (event.client.client_id === "YOUR_ARGOCD_CLIENT_ID") {
  // Only add groups for ArgoCD
  api.idToken.setCustomClaim(namespace + "groups", userGroups);
}
```

This ensures:
- ✅ Groups are only added to tokens destined for ArgoCD
- ✅ Other applications don't receive ArgoCD-specific role information
- ✅ Token size is minimized for other applications
- ✅ Security boundaries are maintained

## Alternative Group Sources

### App Metadata (Recommended for small teams)
```json
{
  "groups": ["konnektr-admins", "konnektr-developers"]
}
```

### Auth0 Roles & Authorization Extension
- More complex but better for larger organizations
- Supports role hierarchies and permissions
- Better audit trail

### External Identity Providers
- SAML/OIDC from corporate directories
- Groups come from AD/LDAP automatically
- Requires Auth0 Enterprise features

## Terraform vs Manual Setup

### Terraform Benefits
- ✅ Infrastructure as Code
- ✅ Reproducible deployments
- ✅ Version controlled
- ✅ Easier to manage multiple environments

### When to Use Manual
- Quick testing/proof of concept
- One-time setup for small environments
- Learning/educational purposes

## Security Best Practices Implemented

1. **Workload Identity**: No service account keys stored in cluster
2. **Least Privilege**: Each service account has minimal required permissions
3. **Secret Rotation**: External Secrets automatically refreshes secrets (15m interval)
4. **Application-Scoped Claims**: Groups only added for ArgoCD application
5. **Private GKE Cluster**: External Secrets runs in private cluster environment