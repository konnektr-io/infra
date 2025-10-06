# ArgoCD Auth0 Integration Setup Guide

This guide covers setting up ArgoCD authentication with Auth0 using external secrets stored in Google Cloud Secret Manager.

## Prerequisites

1. Auth0 tenant
2. Google Cloud Project with Secret Manager API enabled
3. GKE cluster with Workload Identity enabled
4. External Secrets Operator installed (already done via `external-secrets-app.yaml`)

## Step 1: Auth0 Configuration

### Create a Regular Web Application in Auth0

1. Go to Auth0 Dashboard → Applications → Create Application
2. Choose "Regular Web Applications"
3. Configure the following settings:

**Application URIs:**

- Allowed Callback URLs: `https://argocd.konnektr.io/auth/callback`, `https://argocd.konnektr.io/api/dex/callback`
- Allowed Logout URLs: `https://argocd.konnektr.io`
- Allowed Web Origins: `https://argocd.konnektr.io`
- Allowed Origins (CORS): `https://argocd.konnektr.io`

**Grant Types:**

- ✅ Authorization Code
- ✅ Refresh Token

**Note down:**

- Domain (e.g., `konnektr.auth0.com`)
- Client ID (you'll need this for the Action script above)
- Client Secret

### Optional: Configure Custom Claims for Groups (ArgoCD-specific)

If you want to use Auth0 groups/roles in ArgoCD, you should scope them to only the ArgoCD application:

1. Create an Action in Auth0 Dashboard → Actions → Flows → Login
2. Add this code to include groups ONLY for ArgoCD:

```javascript
exports.onExecutePostLogin = async (event, api) => {
  const namespace = "https://argocd.io/";

  // Only add groups claim for ArgoCD application
  if (event.client.client_id === "YOUR_ARGOCD_CLIENT_ID") {
    if (event.authorization) {
      // You can use user.app_metadata.roles, user.user_metadata.groups, or roles from your identity provider
      const userGroups =
        event.user.app_metadata?.groups ||
        event.user.user_metadata?.groups ||
        [];
      api.idToken.setCustomClaim(namespace + "groups", userGroups);
    }
  }
};
```

**Alternative approach using audience:**

```javascript
exports.onExecutePostLogin = async (event, api) => {
  const namespace = "https://argocd.io/";

  // Check if this is for ArgoCD by checking the audience or client
  if (
    event.request.hostname === "konnektr.auth0.com" &&
    event.client.client_id === "YOUR_ARGOCD_CLIENT_ID"
  ) {
    const userGroups = event.user.app_metadata?.groups || [];
    api.idToken.setCustomClaim(namespace + "groups", userGroups);
  }
};
```

### Setting up User Groups in Auth0

To use groups with ArgoCD, you need to assign groups to users:

**Option 1: Using Auth0 App Metadata**

1. Go to Auth0 Dashboard → User Management → Users
2. Select a user → Edit
3. In the `app_metadata` section, add:

```json
{
  "groups": ["konnektr-admins", "konnektr-developers"]
}
```

**Option 2: Using Auth0 Roles (Auth0 Authorization Extension)**

1. Enable the Authorization Extension
2. Create roles like `ArgoCD Admin`, `ArgoCD Viewer`
3. Assign roles to users
4. Modify the Action to use `event.user.roles` instead of groups

## Step 2: Google Cloud Setup

### Option A: Using Terraform (Recommended)

A **separate service account** is created for external-secrets (not reusing the GKE node service account) for better security isolation and least-privilege access. The external-secrets service account is defined in `terraform/external-secrets.tf`. Apply it with:

```bash
cd terraform/
terraform plan
terraform apply
```

### Option B: Manual gcloud commands (if not using Terraform)

```bash
# Create service account for external-secrets
gcloud iam service-accounts create external-secrets \
    --display-name="External Secrets Service Account"

# Grant Secret Manager access
gcloud projects add-iam-policy-binding YOUR_PROJECT_ID \
    --member="serviceAccount:external-secrets@YOUR_PROJECT_ID.iam.gserviceaccount.com" \
    --role="roles/secretmanager.secretAccessor"

# Enable Workload Identity binding
gcloud iam service-accounts add-iam-policy-binding \
    external-secrets@YOUR_PROJECT_ID.iam.gserviceaccount.com \
    --role roles/iam.workloadIdentityUser \
    --member "serviceAccount:YOUR_PROJECT_ID.svc.id.goog[external-secrets/external-secrets-sa]"
```

### Store Auth0 Client Secret in Google Secret Manager

```bash
# Store the Auth0 client secret
echo -n "YOUR_AUTH0_CLIENT_SECRET" | gcloud secrets create argocd-auth0-client-secret --data-file=-
```

## Step 3: Update Configuration Files

### Update argocd-cm.yaml

Replace the placeholders in `kubernetes/argocd/argocd-cm.yaml`:

```yaml
oidc.config: |
  name: Auth0
  issuer: https://konnektr.auth0.com/  # Replace with your Auth0 domain
  clientID: YOUR_ACTUAL_CLIENT_ID     # Replace with your Auth0 client ID
  clientSecret: $oidc.auth0.clientSecret
  requestedScopes: [openid, profile, email, groups]
  requestedIDTokenClaims:
    groups:
      essential: true
```

### Update ClusterSecretStore

Update `kubernetes/platform-apps/external-secrets/cluster-secret-store/base/cluster-secret-store.yaml`:

- Replace `konnektr-io` with your GCP project ID
- Replace `us-central1-c` with your GKE cluster location
- Replace `konnektr-gke` with your GKE cluster name

### Update Workload Identity

Update `kubernetes/platform-apps/external-secrets/cluster-secret-store/base/workload-identity.yaml`:

- Replace `external-secrets@konnektr-io.iam.gserviceaccount.com` with your actual Google Service Account email

## Step 4: Deploy

1. **Deploy the ClusterSecretStore:**

   ```bash
   kubectl apply -k kubernetes/platform/base/
   ```

2. **Deploy ArgoCD with Auth0 configuration:**

   ```bash
   kubectl apply -k kubernetes/argocd/overlays/prd/
   ```

3. **Verify external secret is working:**
   ```bash
   kubectl get externalsecret -n argocd
   kubectl get secret argocd-secret -n argocd -o yaml
   ```

## Step 5: Configure ArgoCD RBAC (Optional)

Create an ArgoCD RBAC configuration to map Auth0 groups to ArgoCD roles:

```yaml
# Add to argocd-cm.yaml
policy.default: role:readonly
policy.csv: |
  p, role:admin, applications, *, */*, allow
  p, role:admin, clusters, *, *, allow
  p, role:admin, repositories, *, *, allow
  g, konnektr-admins, role:admin
```

## Troubleshooting

### Check External Secret Status

```bash
kubectl describe externalsecret argocd-auth0-secret -n argocd
kubectl logs -n external-secrets -l app.kubernetes.io/name=external-secrets
```

### Verify ArgoCD Configuration

```bash
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-server
```

### Test Authentication

1. Navigate to `https://argocd.konnektr.io`
2. Click "LOG IN VIA AUTH0"
3. Authenticate with Auth0
4. Verify successful login and proper user groups

## Security Notes

- The Auth0 client secret is securely stored in Google Secret Manager
- Workload Identity provides secure, keyless authentication to Google Cloud
- External Secrets automatically rotates the secret based on the refresh interval (15m)
- All sensitive configuration is externalized and not stored in Git
