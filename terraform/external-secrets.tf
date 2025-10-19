# External Secrets Service Account for Google Cloud Secret Manager access
resource "google_service_account" "external_secrets" {
  account_id   = "external-secrets"
  display_name = "External Secrets Service Account"
  description  = "Service account for External Secrets to access Google Cloud Secret Manager"
}

# Grant Secret Manager access to external-secrets service account
resource "google_project_iam_member" "external_secrets_secret_accessor" {
  project = var.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${google_service_account.external_secrets.email}"
  depends_on = [google_container_cluster.primary]
}

# Enable Workload Identity binding for external-secrets
resource "google_service_account_iam_member" "external_secrets_workload_identity" {
  service_account_id = google_service_account.external_secrets.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[external-secrets/external-secrets-sa]"
}

# Output the service account email for reference
output "external_secrets_service_account_email" {
  description = "Email of the external-secrets service account"
  value       = google_service_account.external_secrets.email
}
