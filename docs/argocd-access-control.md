# ArgoCD Access Control - Restricting Users to Specific Groups

This guide shows how to ensure ONLY users with `konnektr-admins` or `konnektr-developers` groups can access ArgoCD.

This allows Auth0 login but restricts access within ArgoCD using `policy.default: role:none`.

`argocd-cm.yaml`

```yaml
policy.default: role:none # No permissions by default
policy.csv: |
  # Admin role permissions
  p, role:admin, applications, *, */*, allow
  p, role:admin, clusters, *, *, allow
  p, role:admin, repositories, *, *, allow

  # Developer role permissions (read + sync)
  p, role:developer, applications, get, */*, allow
  p, role:developer, applications, sync, */*, allow
  p, role:developer, repositories, get, *, allow

  # Group to role mappings
  g, konnektr-admins, role:admin
  g, konnektr-developers, role:developer
```

### What This Does

- **Users without groups**: Get `role:none` = no access to anything
- **konnektr-admins**: Get full admin access
- **konnektr-developers**: Get read access + ability to sync applications

## Recommended: Use Both Approaches

For maximum security, use **both approaches**:

1. **Auth0 Action**: Prevents unauthorized users from completing login
2. **ArgoCD RBAC**: Provides defense-in-depth and granular permissions

## Testing Your Setup

### Test 1: Authorized User

```bash
# Add groups to a test user in Auth0 Dashboard
# User Management → Users → Select User → app_metadata:
{
  "groups": ["konnektr-developers"]
}
```

### Test 2: Unauthorized User

```bash
# Create user without any groups or with wrong groups
# Should be blocked at Auth0 level with Approach 1
```

### Test 3: Verify ArgoCD RBAC

```bash
# Login as konnektr-developers user
# Should be able to view apps but not manage clusters/repos
```

## Troubleshooting

### User Can't Login (Good!)

If unauthorized users can't login, this is working correctly. Check:

- Auth0 Action is deployed and active
- User doesn't have required groups in `app_metadata`

### User Can Login But Sees "Insufficient Permissions"

This means Auth0 allowed login but ArgoCD RBAC blocked access:

- Check if groups are properly passed in ID token
- Verify group names match exactly (`konnektr-admins` vs `konnektr-admin`)
- Check ArgoCD logs: `kubectl logs -n argocd -l app.kubernetes.io/name=argocd-server`

### Debug Group Claims

```bash
# Decode JWT token to see if groups are included
# Use https://jwt.io or similar tool
# Look for "https://konnektr.io/groups" claim
```

## Group Permission Matrix

| Group                 | Applications | Repositories | Clusters    | Projects    |
| --------------------- | ------------ | ------------ | ----------- | ----------- |
| `konnektr-admins`     | Full access  | Full access  | Full access | Full access |
| `konnektr-developers` | Read + Sync  | Read only    | No access   | No access   |
| No groups             | No access    | No access    | No access   | No access   |
