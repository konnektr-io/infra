#!/usr/bin/env pwsh
# Bootstrap script for Konnektr GKE cluster
# This script handles the initial installation order for platform components

param(
    [switch]$SkipExternalSecrets,
    [switch]$SkipCertManager,
    [switch]$SkipArgoCD
)

$ErrorActionPreference = "Stop"

Write-Host "=== Konnektr Cluster Bootstrap ===" -ForegroundColor Cyan
Write-Host ""

# Check if kubectl is configured
Write-Host "Checking cluster connection..." -ForegroundColor Yellow
try {
    kubectl cluster-info | Out-Null
    Write-Host "✓ Connected to cluster" -ForegroundColor Green
}
catch {
    Write-Error "Cannot connect to cluster. Run: gcloud container clusters get-credentials konnektr-gke --region europe-west1 --project konnektr"
    exit 1
}

# Step 1: Install External Secrets Operator
if (-not $SkipExternalSecrets) {
    Write-Host ""
    Write-Host "Step 1: Installing External Secrets Operator..." -ForegroundColor Yellow
    
    # Add Helm repo
    Write-Host "  Adding external-secrets Helm repository..."
    helm repo add external-secrets https://charts.external-secrets.io
    helm repo update
    
    # Install ESO
    Write-Host "  Installing external-secrets chart..."
    helm upgrade --install external-secrets `
        external-secrets/external-secrets `
        --namespace external-secrets `
        --create-namespace `
        --version 0.x `
        --set nodeSelector."cloud\.google\.com/gke-spot"="true" `
        --set terminationGracePeriodSeconds=15 `
        --set webhook.nodeSelector."cloud\.google\.com/gke-spot"="true" `
        --set webhook.terminationGracePeriodSeconds=15 `
        --set certController.nodeSelector."cloud\.google\.com/gke-spot"="true" `
        --set certController.terminationGracePeriodSeconds=15 `
        --wait
    
    Write-Host "✓ External Secrets Operator installed" -ForegroundColor Green
    
    # Step 2: Apply ClusterSecretStore
    Write-Host ""
    Write-Host "Step 2: Creating ClusterSecretStore..." -ForegroundColor Yellow
    kubectl apply -f ../kubernetes/platform/base/external-secrets-cluster-store.yaml
    Write-Host "✓ ClusterSecretStore created" -ForegroundColor Green
    
    # Wait for ESO to be ready
    Write-Host ""
    Write-Host "Waiting for External Secrets Operator to be ready..." -ForegroundColor Yellow
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=external-secrets -n external-secrets --timeout=120s
    Write-Host "✓ External Secrets Operator is ready" -ForegroundColor Green
}

# Step 3: Install cert-manager
if (-not $SkipCertManager) {
    Write-Host ""
    Write-Host "Step 3: Installing cert-manager..." -ForegroundColor Yellow
    
    # Add Helm repo
    Write-Host "  Adding cert-manager Helm repository..."
    helm repo add jetstack https://charts.jetstack.io
    helm repo update
    
    # Install cert-manager with CRDs
    Write-Host "  Installing cert-manager chart with CRDs..."
    helm upgrade --install cert-manager `
        jetstack/cert-manager `
        --namespace cert-manager `
        --create-namespace `
        --version v1.19.1 `
        --set crds.enabled=true `
        --set featureGates="ExperimentalGatewayAPISupport=true" `
        --set nodeSelector."cloud\.google\.com/gke-spot"="true" `
        --set webhook.nodeSelector."cloud\.google\.com/gke-spot"="true" `
        --set cainjector.nodeSelector."cloud\.google\.com/gke-spot"="true" `
        --set startupapicheck.nodeSelector."cloud\.google\.com/gke-spot"="true" `
        --wait
    
    Write-Host "✓ cert-manager installed" -ForegroundColor Green
    
    # Wait for cert-manager to be ready
    Write-Host ""
    Write-Host "Waiting for cert-manager to be ready..." -ForegroundColor Yellow
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=cert-manager -n cert-manager --timeout=120s
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=webhook -n cert-manager --timeout=120s
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=cainjector -n cert-manager --timeout=120s
    
    # Verify CRDs are installed
    Write-Host ""
    Write-Host "Verifying cert-manager CRDs..." -ForegroundColor Yellow
    $crdCount = (kubectl get crd | Select-String "cert-manager.io").Count
    if ($crdCount -lt 6) {
        Write-Error "Expected at least 6 cert-manager CRDs, found $crdCount"
        exit 1
    }
    Write-Host "✓ cert-manager CRDs installed ($crdCount found)" -ForegroundColor Green
}

# Step 4: Install ArgoCD
if (-not $SkipArgoCD) {
    Write-Host ""
    Write-Host "Step 4: Installing ArgoCD..." -ForegroundColor Yellow
    kubectl apply -k ../kubernetes/argocd/overlays/prd -n argocd
    
    # Wait for CRDs to be established before second apply
    Write-Host ""
    Write-Host "Waiting for ArgoCD CRDs to be established..." -ForegroundColor Yellow
    Start-Sleep -Seconds 5
    
    # Apply again to ensure all resources are created (fixes webhook timing issues)
    Write-Host "  Applying ArgoCD manifests (second pass)..." -ForegroundColor Yellow
    kubectl apply -k ../kubernetes/argocd/overlays/prd -n argocd
    
    Write-Host ""
    Write-Host "Waiting for ArgoCD to be ready..." -ForegroundColor Yellow
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server -n argocd --timeout=300s
    
    Write-Host "✓ ArgoCD installed" -ForegroundColor Green
}

Write-Host ""
Write-Host "=== Bootstrap Complete ===" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "1. Check ArgoCD is healthy: kubectl get pods -n argocd"
Write-Host "2. Access ArgoCD UI: https://argocd.konnektr.io"
Write-Host "3. Get admin password: kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
Write-Host ""
Write-Host "Note: ArgoCD will automatically adopt the Helm releases (external-secrets, cert-manager)." -ForegroundColor Yellow
Write-Host "      You can verify in the ArgoCD UI that these apps are synced and healthy." -ForegroundColor Yellow
