#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Wakes up the hibernated GKE cluster by unsuspending ArgoCD applications.

.DESCRIPTION
    This script restores automated sync policies on all ArgoCD Applications and ApplicationSets.
    ArgoCD will then automatically reconcile and restore all workloads to their desired state.
    GKE Autopilot will provision spot nodes as pods are scheduled.

.PARAMETER DryRun
    If specified, shows what would be done without making changes.

.EXAMPLE
    .\cluster-wakeup.ps1
    Wakes up the cluster

.EXAMPLE
    .\cluster-wakeup.ps1 -DryRun
    Shows what would be changed without making changes
#>

[CmdletBinding()]
param(
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

Write-Host "☀️  Starting cluster wakeup..." -ForegroundColor Cyan
Write-Host ""

if ($DryRun) {
    Write-Host "⚠️  DRY RUN MODE - No changes will be made" -ForegroundColor Yellow
    Write-Host ""
}

# Function to run kubectl command
function Invoke-Kubectl {
    param([string[]]$Arguments)
    
    if ($DryRun) {
        Write-Host "  [DRY RUN] kubectl $($Arguments -join ' ')" -ForegroundColor Gray
        return
    }
    
    kubectl @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "kubectl command failed with exit code $LASTEXITCODE"
    }
}

# Step 1: Restore automated sync for ArgoCD Applications
Write-Host "📦 Restoring ArgoCD Applications..." -ForegroundColor Yellow

try {
    # Get all Applications
    $apps = kubectl get applications -n argocd -o json | ConvertFrom-Json
    
    foreach ($app in $apps.items) {
        $appName = $app.metadata.name
        
        # Check if automated sync is already configured
        if ($app.spec.syncPolicy.automated) {
            Write-Host "  Skipping (already automated): $appName" -ForegroundColor Gray
            continue
        }
        
        Write-Host "  Restoring: $appName" -ForegroundColor Gray
        
        if (-not $DryRun) {
            # Restore automated sync policy
            kubectl patch application $appName -n argocd --type=json -p='[{"op": "add", "path": "/spec/syncPolicy/automated", "value": {"prune": true, "selfHeal": true}}]'
        }
    }
    
    Write-Host "✓ Restored $($apps.items.Count) Applications" -ForegroundColor Green
}
catch {
    Write-Host "⚠️  Warning: Failed to restore Applications: $_" -ForegroundColor Yellow
}

Write-Host ""

# Step 2: Restore automated sync for ArgoCD ApplicationSets
Write-Host "📦 Restoring ArgoCD ApplicationSets..." -ForegroundColor Yellow

try {
    # Get all ApplicationSets
    $appsets = kubectl get applicationsets -n argocd -o json | ConvertFrom-Json
    
    foreach ($appset in $appsets.items) {
        $appsetName = $appset.metadata.name
        
        # Check if automated sync is already configured
        if ($appset.spec.template.spec.syncPolicy.automated) {
            Write-Host "  Skipping (already automated): $appsetName" -ForegroundColor Gray
            continue
        }
        
        Write-Host "  Restoring: $appsetName" -ForegroundColor Gray
        
        if (-not $DryRun) {
            # Restore automated sync policy in template
            kubectl patch applicationset $appsetName -n argocd --type=json -p='[{"op": "add", "path": "/spec/template/spec/syncPolicy/automated", "value": {"prune": true, "selfHeal": true}}]'
        }
    }
    
    Write-Host "✓ Restored $($appsets.items.Count) ApplicationSets" -ForegroundColor Green
}
catch {
    Write-Host "⚠️  Warning: Failed to restore ApplicationSets: $_" -ForegroundColor Yellow
}

Write-Host ""

# Step 3: Wait for ArgoCD to reconcile
if (-not $DryRun) {
    Write-Host "⏳ Waiting for ArgoCD to reconcile applications..." -ForegroundColor Yellow
    Write-Host "   This may take 5-10 minutes for all workloads to start." -ForegroundColor Gray
    Write-Host ""
    
    $maxWait = 600  # 10 minutes
    $waited = 0
    $interval = 10
    
    while ($waited -lt $maxWait) {
        try {
            $apps = kubectl get applications -n argocd -o json | ConvertFrom-Json
            $syncing = ($apps.items | Where-Object { $_.status.sync.status -ne "Synced" }).Count
            $healthy = ($apps.items | Where-Object { $_.status.health.status -eq "Healthy" }).Count
            $total = $apps.items.Count
            
            Write-Host "  Status: $healthy/$total healthy, $syncing syncing..." -ForegroundColor Gray
            
            if ($syncing -eq 0 -and $healthy -eq $total) {
                Write-Host "✓ All applications synced and healthy" -ForegroundColor Green
                break
            }
            
            Start-Sleep -Seconds $interval
            $waited += $interval
        }
        catch {
            Write-Host "  Waiting for ArgoCD to start..." -ForegroundColor Gray
            Start-Sleep -Seconds $interval
            $waited += $interval
        }
    }
    
    if ($waited -ge $maxWait) {
        Write-Host "⚠️  Timeout waiting for full reconciliation (applications may still be syncing)" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "✅ Cluster wakeup complete!" -ForegroundColor Green
Write-Host ""
Write-Host "💡 You can monitor the status with:" -ForegroundColor Cyan
Write-Host "   kubectl get applications -n argocd" -ForegroundColor White
Write-Host "   kubectl get pods --all-namespaces" -ForegroundColor White
Write-Host ""
Write-Host "🌐 Access ArgoCD UI:" -ForegroundColor Cyan
Write-Host "   kubectl port-forward svc/argocd-server -n argocd 8080:443" -ForegroundColor White
Write-Host "   Then open: https://localhost:8080" -ForegroundColor White
Write-Host ""
Write-Host "💰 Cluster is now running on spot nodes (savings: ~70% vs regular nodes)" -ForegroundColor Green
