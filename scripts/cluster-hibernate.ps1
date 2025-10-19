#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Hibernates the GKE cluster by suspending ArgoCD applications and scaling workloads to 0.

.DESCRIPTION
    This script suspends all ArgoCD Applications and ApplicationSets to prevent auto-healing,
    then scales all Deployments and StatefulSets to 0 replicas. GKE Autopilot will automatically
    scale nodes to 0 when no pods are running, saving costs.

.PARAMETER DryRun
    If specified, shows what would be done without making changes.

.EXAMPLE
    .\cluster-hibernate.ps1
    Hibernates the cluster

.EXAMPLE
    .\cluster-hibernate.ps1 -DryRun
    Shows what would be hibernated without making changes
#>

[CmdletBinding()]
param(
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

Write-Host "🌙 Starting cluster hibernation..." -ForegroundColor Cyan
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

# Step 1: Suspend all ArgoCD Applications
Write-Host "📦 Suspending ArgoCD Applications..." -ForegroundColor Yellow

try {
    # Get all Applications
    $apps = kubectl get applications -n argocd -o json | ConvertFrom-Json
    
    foreach ($app in $apps.items) {
        $appName = $app.metadata.name
        Write-Host "  Suspending: $appName" -ForegroundColor Gray
        
        if (-not $DryRun) {
            # Suspend by removing automated sync policy
            kubectl patch application $appName -n argocd --type=json -p='[{"op": "remove", "path": "/spec/syncPolicy/automated"}]' 2>$null
        }
    }
    
    Write-Host "✓ Suspended $($apps.items.Count) Applications" -ForegroundColor Green
}
catch {
    Write-Host "⚠️  Warning: Failed to suspend Applications: $_" -ForegroundColor Yellow
}

Write-Host ""

# Step 2: Suspend all ArgoCD ApplicationSets
Write-Host "📦 Suspending ArgoCD ApplicationSets..." -ForegroundColor Yellow

try {
    # Get all ApplicationSets
    $appsets = kubectl get applicationsets -n argocd -o json | ConvertFrom-Json
    
    foreach ($appset in $appsets.items) {
        $appsetName = $appset.metadata.name
        Write-Host "  Suspending: $appsetName" -ForegroundColor Gray
        
        if (-not $DryRun) {
            # Suspend by removing automated sync policy in template
            kubectl patch applicationset $appsetName -n argocd --type=json -p='[{"op": "remove", "path": "/spec/template/spec/syncPolicy/automated"}]' 2>$null
        }
    }
    
    Write-Host "✓ Suspended $($appsets.items.Count) ApplicationSets" -ForegroundColor Green
}
catch {
    Write-Host "⚠️  Warning: Failed to suspend ApplicationSets: $_" -ForegroundColor Yellow
}

Write-Host ""

# Step 3: Scale all Deployments to 0 (except kube-system)
Write-Host "📉 Scaling Deployments to 0..." -ForegroundColor Yellow

try {
    $deployments = kubectl get deployments --all-namespaces -o json | ConvertFrom-Json
    $scaledCount = 0
    
    foreach ($deploy in $deployments.items) {
        $namespace = $deploy.metadata.namespace
        $name = $deploy.metadata.name
        
        # Skip kube-system and gke-managed namespaces
        if ($namespace -in @("kube-system", "kube-public", "kube-node-lease", "gke-managed-system")) {
            continue
        }
        
        $currentReplicas = $deploy.spec.replicas
        if ($currentReplicas -eq 0) {
            continue
        }
        
        Write-Host "  $namespace/$name (replicas: $currentReplicas -> 0)" -ForegroundColor Gray
        Invoke-Kubectl -Arguments @("scale", "deployment", $name, "-n", $namespace, "--replicas=0")
        $scaledCount++
    }
    
    Write-Host "✓ Scaled $scaledCount Deployments to 0" -ForegroundColor Green
}
catch {
    Write-Host "⚠️  Warning: Failed to scale Deployments: $_" -ForegroundColor Yellow
}

Write-Host ""

# Step 4: Scale all StatefulSets to 0 (except kube-system)
Write-Host "📉 Scaling StatefulSets to 0..." -ForegroundColor Yellow

try {
    $statefulsets = kubectl get statefulsets --all-namespaces -o json | ConvertFrom-Json
    $scaledCount = 0
    
    foreach ($sts in $statefulsets.items) {
        $namespace = $sts.metadata.namespace
        $name = $sts.metadata.name
        
        # Skip kube-system and gke-managed namespaces
        if ($namespace -in @("kube-system", "kube-public", "kube-node-lease", "gke-managed-system")) {
            continue
        }
        
        $currentReplicas = $sts.spec.replicas
        if ($currentReplicas -eq 0) {
            continue
        }
        
        Write-Host "  $namespace/$name (replicas: $currentReplicas -> 0)" -ForegroundColor Gray
        Invoke-Kubectl -Arguments @("scale", "statefulset", $name, "-n", $namespace, "--replicas=0")
        $scaledCount++
    }
    
    Write-Host "✓ Scaled $scaledCount StatefulSets to 0" -ForegroundColor Green
}
catch {
    Write-Host "⚠️  Warning: Failed to scale StatefulSets: $_" -ForegroundColor Yellow
}

Write-Host ""

# Step 5: Wait for pods to terminate
if (-not $DryRun) {
    Write-Host "⏳ Waiting for pods to terminate..." -ForegroundColor Yellow
    
    $maxWait = 300  # 5 minutes
    $waited = 0
    $interval = 5
    
    while ($waited -lt $maxWait) {
        $pods = kubectl get pods --all-namespaces --field-selector=status.phase!=Succeeded, status.phase!=Failed -o json | ConvertFrom-Json
        $userPods = $pods.items | Where-Object { 
            $_.metadata.namespace -notin @("kube-system", "kube-public", "kube-node-lease", "gke-managed-system")
        }
        
        if ($userPods.Count -eq 0) {
            Write-Host "✓ All user pods terminated" -ForegroundColor Green
            break
        }
        
        Write-Host "  Waiting for $($userPods.Count) pods to terminate..." -ForegroundColor Gray
        Start-Sleep -Seconds $interval
        $waited += $interval
    }
    
    if ($waited -ge $maxWait) {
        Write-Host "⚠️  Timeout waiting for pods to terminate (some may still be running)" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "✅ Cluster hibernation complete!" -ForegroundColor Green
Write-Host ""
Write-Host "💡 GKE Autopilot will automatically scale nodes to 0 within a few minutes." -ForegroundColor Cyan
Write-Host "💡 To wake up the cluster, run: .\cluster-wakeup.ps1" -ForegroundColor Cyan
Write-Host ""
Write-Host "💰 Estimated cost while hibernated: ~\$0/month (only storage)" -ForegroundColor Green
