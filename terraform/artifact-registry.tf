
# Grant Artifact Registry Reader to default Compute Engine service account for GKE Autopilot
resource "google_project_iam_member" "artifact_registry_reader" {
  project = var.project_id
  role    = "roles/artifactregistry.reader"
  member  = "serviceAccount:${var.project_number}-compute@developer.gserviceaccount.com"
}

// Artifact Registry for Docker images
resource "google_artifact_registry_repository" "docker_repo" {
  provider      = google
  location      = var.region
  repository_id = var.artifact_registry_name
  description   = "Docker Artifact Registry for Konnektr"
  format        = "DOCKER"
}
