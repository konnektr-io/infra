# GitHub Webhook Secret Setup for ArgoCD (PowerShell)

Write-Host "🔐 Setting up GitHub webhook secret for ArgoCD..." -ForegroundColor Blue
Write-Host ""

# Check if gcloud is available
if (-not (Get-Command gcloud -ErrorAction SilentlyContinue)) {
    Write-Host "❌ gcloud CLI is not installed. Please install it first." -ForegroundColor Red
    exit 1
}

# Generate secure webhook secret (32 random bytes as hex)
Write-Host "🔑 Generating secure webhook secret..." -ForegroundColor Yellow
$bytes = New-Object byte[] 32
[System.Security.Cryptography.RNGCryptoServiceProvider]::Create().GetBytes($bytes)
$WEBHOOK_SECRET = [System.BitConverter]::ToString($bytes) -replace '-', ''
$WEBHOOK_SECRET = $WEBHOOK_SECRET.ToLower()

Write-Host "✅ Generated webhook secret: $WEBHOOK_SECRET" -ForegroundColor Green
Write-Host ""

# Store in Google Secret Manager
Write-Host "☁️  Storing secret in Google Secret Manager..." -ForegroundColor Yellow

try {
    # Try to create new secret
    $WEBHOOK_SECRET | gcloud secrets create argocd-github-webhook-secret --data-file=-
    Write-Host "✅ Secret created in Google Secret Manager" -ForegroundColor Green
}
catch {
    # If secret exists, add new version
    Write-Host "Secret already exists, updating version..." -ForegroundColor Yellow
    $WEBHOOK_SECRET | gcloud secrets versions add argocd-github-webhook-secret --data-file=-
    Write-Host "✅ Secret updated in Google Secret Manager" -ForegroundColor Green
}

Write-Host ""
Write-Host "📋 Next steps:" -ForegroundColor Cyan
Write-Host "1. Deploy ArgoCD configuration:"
Write-Host "   kubectl apply -k kubernetes/argocd/overlays/prd/"
Write-Host ""
Write-Host "2. Configure GitHub webhooks with this secret:"
Write-Host "   Secret: $WEBHOOK_SECRET" -ForegroundColor Yellow
Write-Host "   URL: https://argocd.konnektr.io/api/webhook"
Write-Host ""
Write-Host "3. Test webhook delivery in GitHub repository settings"
Write-Host ""

# Save secret to temporary file for easy copy-paste
$tempFile = "$env:TEMP\argocd-webhook-secret.txt"
$WEBHOOK_SECRET | Out-File -FilePath $tempFile -Encoding utf8
Write-Host "💾 Secret also saved to: $tempFile" -ForegroundColor Green
Write-Host "   (Please delete this file after configuring GitHub webhooks)"
Write-Host ""

# Copy to clipboard if possible
try {
    $WEBHOOK_SECRET | Set-Clipboard
    Write-Host "📋 Secret copied to clipboard!" -ForegroundColor Green
}
catch {
    Write-Host "💡 Tip: Copy the secret from the temp file for GitHub webhook configuration" -ForegroundColor Blue
}