# Automated Hibernation with GitHub Actions (Optional)

This guide shows how to automate cluster hibernation on a schedule using GitHub Actions.

## Use Cases

- **Nightly hibernation**: Automatically hibernate at 6 PM, wake at 8 AM
- **Weekend hibernation**: Hibernate Friday evening, wake Monday morning
- **Vacation mode**: One-click hibernation for extended periods

## Setup

### 1. GKE Cluster Credentials

Add GKE credentials to GitHub Secrets:

```bash
# Get service account key
gcloud iam service-accounts keys create key.json \
  --iam-account=github-actions@konnektr.iam.gserviceaccount.com

# Base64 encode for GitHub Secret
cat key.json | base64 -w 0
```

**GitHub Settings** → **Secrets** → **Actions** → Add:

- Name: `GKE_SA_KEY`
- Value: (base64 encoded key from above)

Also add:

- `GKE_PROJECT`: `konnektr`
- `GKE_CLUSTER`: `konnektr-gke`
- `GKE_REGION`: `europe-west1`

### 2. Create Workflow File

Create `.github/workflows/cluster-schedule.yml`:

```yaml
name: Cluster Hibernation Schedule

on:
  schedule:
    # Hibernate at 6 PM UTC (Mon-Fri)
    - cron: "0 18 * * 1-5"
    # Wake up at 8 AM UTC (Mon-Fri)
    - cron: "0 8 * * 1-5"
    # Hibernate Friday 6 PM for weekend
    - cron: "0 18 * * 5"
    # Wake up Monday 8 AM after weekend
    - cron: "0 8 * * 1"

  # Allow manual trigger
  workflow_dispatch:
    inputs:
      action:
        description: "Action to perform"
        required: true
        type: choice
        options:
          - hibernate
          - wakeup
          - status

env:
  GKE_PROJECT: ${{ secrets.GKE_PROJECT }}
  GKE_CLUSTER: ${{ secrets.GKE_CLUSTER }}
  GKE_REGION: ${{ secrets.GKE_REGION }}

jobs:
  cluster-management:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Google Cloud SDK
        uses: google-github-actions/setup-gcloud@v2
        with:
          service_account_key: ${{ secrets.GKE_SA_KEY }}
          project_id: ${{ env.GKE_PROJECT }}
          export_default_credentials: true

      - name: Configure kubectl
        run: |
          gcloud container clusters get-credentials ${{ env.GKE_CLUSTER }} \
            --region ${{ env.GKE_REGION }} \
            --project ${{ env.GKE_PROJECT }}

      - name: Install PowerShell
        run: |
          sudo apt-get update
          sudo apt-get install -y wget apt-transport-https software-properties-common
          wget -q "https://packages.microsoft.com/config/ubuntu/$(lsb_release -rs)/packages-microsoft-prod.deb"
          sudo dpkg -i packages-microsoft-prod.deb
          sudo apt-get update
          sudo apt-get install -y powershell

      - name: Determine action
        id: action
        run: |
          if [ "${{ github.event_name }}" == "workflow_dispatch" ]; then
            echo "action=${{ github.event.inputs.action }}" >> $GITHUB_OUTPUT
          else
            # Determine based on time
            hour=$(date -u +%H)
            day=$(date -u +%u)
            
            if [ "$hour" == "18" ]; then
              echo "action=hibernate" >> $GITHUB_OUTPUT
            elif [ "$hour" == "08" ]; then
              echo "action=wakeup" >> $GITHUB_OUTPUT
            else
              echo "action=status" >> $GITHUB_OUTPUT
            fi
          fi

      - name: Hibernate cluster
        if: steps.action.outputs.action == 'hibernate'
        run: |
          echo "🌙 Hibernating cluster..."
          pwsh -File scripts/cluster-hibernate.ps1

      - name: Wake up cluster
        if: steps.action.outputs.action == 'wakeup'
        run: |
          echo "☀️ Waking up cluster..."
          pwsh -File scripts/cluster-wakeup.ps1

      - name: Check status
        if: steps.action.outputs.action == 'status'
        run: |
          echo "📊 Checking cluster status..."
          kubectl get nodes
          kubectl get applications -n argocd
          kubectl get pods --all-namespaces --field-selector=status.phase!=Succeeded,status.phase!=Failed | grep -v "kube-system" || echo "No user pods running"

      - name: Send notification (optional)
        if: always()
        uses: 8398a7/action-slack@v3
        with:
          status: ${{ job.status }}
          text: |
            Cluster ${{ steps.action.outputs.action }} completed
            Project: ${{ env.GKE_PROJECT }}
            Cluster: ${{ env.GKE_CLUSTER }}
          webhook_url: ${{ secrets.SLACK_WEBHOOK }}
        env:
          SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK }}
```

### 3. Adjust Schedule

Modify cron expressions for your timezone:

```yaml
schedule:
  # Example: Pacific Time (PST/PDT = UTC-8/-7)
  # Hibernate at 6 PM PST = 2 AM UTC next day
  - cron: "0 2 * * 2-6" # Tue-Sat morning UTC

  # Wake up at 8 AM PST = 4 PM UTC previous day
  - cron: "0 16 * * 1-5" # Mon-Fri afternoon UTC
```

**Cron format**: `minute hour day-of-month month day-of-week`

- `*` = any
- `1-5` = Monday through Friday
- `0 18 * * 1-5` = 6 PM UTC, Monday-Friday

### 4. Test Workflow

Test manually before enabling schedule:

1. Go to **Actions** tab in GitHub
2. Select **Cluster Hibernation Schedule**
3. Click **Run workflow**
4. Choose action: `hibernate`, `wakeup`, or `status`
5. Click **Run workflow**

## Alternative: Simple Bash Scripts

If you prefer bash over PowerShell in CI:

**`.github/workflows/hibernate.sh`:**

```bash
#!/bin/bash
set -e

echo "🌙 Hibernating cluster..."

# Suspend all Applications
kubectl get applications -n argocd -o name | while read app; do
  kubectl patch $app -n argocd --type=json \
    -p='[{"op": "remove", "path": "/spec/syncPolicy/automated"}]' 2>/dev/null || true
done

# Suspend all ApplicationSets
kubectl get applicationsets -n argocd -o name | while read appset; do
  kubectl patch $appset -n argocd --type=json \
    -p='[{"op": "remove", "path": "/spec/template/spec/syncPolicy/automated"}]' 2>/dev/null || true
done

# Scale Deployments to 0
kubectl get deployments --all-namespaces -o json | \
  jq -r '.items[] | select(.metadata.namespace | IN("kube-system", "kube-public", "kube-node-lease", "gke-managed-system") | not) | "\(.metadata.namespace) \(.metadata.name)"' | \
  while read ns name; do
    kubectl scale deployment $name -n $ns --replicas=0
  done

# Scale StatefulSets to 0
kubectl get statefulsets --all-namespaces -o json | \
  jq -r '.items[] | select(.metadata.namespace | IN("kube-system", "kube-public", "kube-node-lease", "gke-managed-system") | not) | "\(.metadata.namespace) \(.metadata.name)"' | \
  while read ns name; do
    kubectl scale statefulset $name -n $ns --replicas=0
  done

echo "✅ Hibernation complete"
```

**`.github/workflows/wakeup.sh`:**

```bash
#!/bin/bash
set -e

echo "☀️ Waking up cluster..."

# Restore automated sync for Applications
kubectl get applications -n argocd -o json | \
  jq -r '.items[] | select(.spec.syncPolicy.automated == null) | .metadata.name' | \
  while read app; do
    kubectl patch application $app -n argocd --type=json \
      -p='[{"op": "add", "path": "/spec/syncPolicy/automated", "value": {"prune": true, "selfHeal": true}}]'
  done

# Restore automated sync for ApplicationSets
kubectl get applicationsets -n argocd -o json | \
  jq -r '.items[] | select(.spec.template.spec.syncPolicy.automated == null) | .metadata.name' | \
  while read appset; do
    kubectl patch applicationset $appset -n argocd --type=json \
      -p='[{"op": "add", "path": "/spec/template/spec/syncPolicy/automated", "value": {"prune": true, "selfHeal": true}}]'
  done

echo "✅ Wakeup complete"
echo "⏳ Waiting for ArgoCD to reconcile..."

# Wait for applications to sync
sleep 60
kubectl get applications -n argocd
```

Then use in workflow:

```yaml
- name: Hibernate cluster
  run: |
    chmod +x .github/workflows/hibernate.sh
    ./.github/workflows/hibernate.sh
```

## Cost Savings with Automation

**Without automation** (manual hibernation):

- Forget to hibernate → Wasted nights/weekends
- Cost: ~$60-100/month

**With automation** (auto-hibernate nights + weekends):

- Automated hibernation → Consistent savings
- Cost: ~$20-40/month (60% additional savings)

## Notifications

### Slack Integration

Add to workflow:

```yaml
- name: Notify Slack
  uses: slackapi/slack-github-action@v1.24.0
  with:
    payload: |
      {
        "text": "🌙 Cluster hibernated for the night",
        "blocks": [
          {
            "type": "section",
            "text": {
              "type": "mrkdwn",
              "text": "*Cluster Status*\n💤 Hibernated"
            }
          }
        ]
      }
  env:
    SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK }}
```

### Email (GitHub Actions)

GitHub automatically emails on workflow failures. No extra config needed.

## Security Considerations

1. **Service Account Permissions**: Create dedicated SA with minimal permissions
2. **Secret Rotation**: Rotate `GKE_SA_KEY` regularly
3. **Branch Protection**: Protect workflow files from unauthorized changes
4. **Audit Logs**: Monitor GitHub Actions audit logs

## Disabling Automated Hibernation

**Temporarily:**

1. Go to **Actions** → **Cluster Hibernation Schedule**
2. Click **⋮** → **Disable workflow**

**Permanently:**

1. Delete `.github/workflows/cluster-schedule.yml`
2. Or comment out the `schedule:` section

## Manual Override

Even with automation, you can manually control:

```powershell
# Override auto-hibernation (keep running tonight)
# Just wake it up after auto-hibernate runs
.\scripts\cluster-wakeup.ps1

# Force hibernation during the day
.\scripts\cluster-hibernate.ps1
```

## Troubleshooting

**Workflow fails with "unauthorized":**

- Check `GKE_SA_KEY` secret is valid
- Verify service account has `container.clusters.get` permission

**Cluster doesn't hibernate:**

- Check GitHub Actions logs
- Verify workflow schedule timezone
- Test manually with workflow_dispatch

**Unexpected wakeups:**

- Check for other automation (CI/CD pipelines)
- Review ArgoCD webhooks
- Check if developers manually un-suspended apps
