#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Validates that all workloads are configured for spot nodes.

.DESCRIPTION
    This script checks that all Deployments, StatefulSets, and CNPG Clusters
    have the correct spot node selectors or affinity rules configured.

.EXAMPLE
    .\validate-spot-config.ps1
#>

$ErrorActionPreference = "Stop"

Write-Host "🔍 Validating spot node configuration..." -ForegroundColor Cyan
Write-Host ""

$issues = @()

# Check if kubectl is available
try {
    kubectl version --client --output=json | Out-Null
}
catch {
    Write-Host "❌ kubectl not found. Please install kubectl and configure cluster access." -ForegroundColor Red
    exit 1
}

# Function to check if resource has spot node selector
function Test-SpotNodeSelector {
    param(
        [string]$Kind,
        [string]$Name,
        [string]$Namespace,
        [object]$Spec
    )
    
    $hasSpotSelector = $false
    $hasSpotAffinity = $false
    
    # Check nodeSelector
    if ($Spec.template.spec.nodeSelector.'cloud.google.com/gke-spot' -eq "true") {
        $hasSpotSelector = $true
    }
    
    # Check affinity
    if ($Spec.template.spec.affinity.nodeAffinity.requiredDuringSchedulingIgnoredDuringExecution) {
        $nodeSelectorTerms = $Spec.template.spec.affinity.nodeAffinity.requiredDuringSchedulingIgnoredDuringExecution.nodeSelectorTerms
        foreach ($term in $nodeSelectorTerms) {
            foreach ($expr in $term.matchExpressions) {
                if ($expr.key -eq "cloud.google.com/gke-spot" -and "true" -in $expr.values) {
                    $hasSpotAffinity = $true
                    break
                }
            }
        }
    }
    
    if (-not $hasSpotSelector -and -not $hasSpotAffinity) {
        return @{
            Valid   = $false
            Message = "❌ $Kind $Namespace/$Name - Missing spot node selector/affinity"
        }
    }
    
    return @{
        Valid   = $true
        Message = "✓ $Kind $Namespace/$Name"
    }
}

# Check Deployments
Write-Host "📦 Checking Deployments..." -ForegroundColor Yellow

try {
    $deployments = kubectl get deployments --all-namespaces -o json | ConvertFrom-Json
    
    foreach ($deploy in $deployments.items) {
        $namespace = $deploy.metadata.namespace
        $name = $deploy.metadata.name
        
        # Skip system namespaces
        if ($namespace -in @("kube-system", "kube-public", "kube-node-lease", "gke-managed-system")) {
            continue
        }
        
        $result = Test-SpotNodeSelector -Kind "Deployment" -Name $name -Namespace $namespace -Spec $deploy.spec
        
        if ($result.Valid) {
            Write-Host "  $($result.Message)" -ForegroundColor Green
        }
        else {
            Write-Host "  $($result.Message)" -ForegroundColor Red
            $issues += $result.Message
        }
    }
}
catch {
    Write-Host "  ⚠️  Failed to check Deployments: $_" -ForegroundColor Yellow
}

Write-Host ""

# Check StatefulSets
Write-Host "📦 Checking StatefulSets..." -ForegroundColor Yellow

try {
    $statefulsets = kubectl get statefulsets --all-namespaces -o json | ConvertFrom-Json
    
    foreach ($sts in $statefulsets.items) {
        $namespace = $sts.metadata.namespace
        $name = $sts.metadata.name
        
        # Skip system namespaces
        if ($namespace -in @("kube-system", "kube-public", "kube-node-lease", "gke-managed-system")) {
            continue
        }
        
        $result = Test-SpotNodeSelector -Kind "StatefulSet" -Name $name -Namespace $namespace -Spec $sts.spec
        
        if ($result.Valid) {
            Write-Host "  $($result.Message)" -ForegroundColor Green
        }
        else {
            Write-Host "  $($result.Message)" -ForegroundColor Red
            $issues += $result.Message
        }
    }
}
catch {
    Write-Host "  ⚠️  Failed to check StatefulSets: $_" -ForegroundColor Yellow
}

Write-Host ""

# Check CNPG Clusters
Write-Host "🗄️  Checking CNPG Clusters..." -ForegroundColor Yellow

try {
    $clusters = kubectl get clusters.postgresql.cnpg.io --all-namespaces -o json 2>$null | ConvertFrom-Json
    
    foreach ($cluster in $clusters.items) {
        $namespace = $cluster.metadata.namespace
        $name = $cluster.metadata.name
        
        $hasSpotAffinity = $false
        
        if ($cluster.spec.affinity.nodeAffinity.requiredDuringSchedulingIgnoredDuringExecution) {
            $nodeSelectorTerms = $cluster.spec.affinity.nodeAffinity.requiredDuringSchedulingIgnoredDuringExecution.nodeSelectorTerms
            foreach ($term in $nodeSelectorTerms) {
                foreach ($expr in $term.matchExpressions) {
                    if ($expr.key -eq "cloud.google.com/gke-spot" -and "true" -in $expr.values) {
                        $hasSpotAffinity = $true
                        break
                    }
                }
            }
        }
        
        if ($hasSpotAffinity) {
            Write-Host "  ✓ Cluster $namespace/$name" -ForegroundColor Green
        }
        else {
            Write-Host "  ❌ Cluster $namespace/$name - Missing spot node affinity" -ForegroundColor Red
            $issues += "❌ Cluster $namespace/$name - Missing spot node affinity"
        }
    }
}
catch {
    Write-Host "  ⚠️  No CNPG Clusters found or failed to check" -ForegroundColor Gray
}

Write-Host ""

# Summary
if ($issues.Count -eq 0) {
    Write-Host "✅ All workloads are configured for spot nodes!" -ForegroundColor Green
    Write-Host ""
    Write-Host "💡 Next steps:" -ForegroundColor Cyan
    Write-Host "   1. Commit and push changes to trigger ArgoCD sync" -ForegroundColor White
    Write-Host "   2. Test hibernation: .\scripts\cluster-hibernate.ps1" -ForegroundColor White
    Write-Host "   3. Test wakeup: .\scripts\cluster-wakeup.ps1" -ForegroundColor White
    exit 0
}
else {
    Write-Host "❌ Found $($issues.Count) issue(s):" -ForegroundColor Red
    Write-Host ""
    foreach ($issue in $issues) {
        Write-Host "  $issue" -ForegroundColor Red
    }
    Write-Host ""
    Write-Host "💡 Review the docs/cost-optimization.md guide for configuration details." -ForegroundColor Yellow
    exit 1
}
