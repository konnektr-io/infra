// Artifact Registry for Docker images
resource "google_artifact_registry_repository" "docker_repo" {
  provider      = google
  location      = var.region
  repository_id = var.artifact_registry_name
  description   = "Docker Artifact Registry for Konnektr"
  format        = "DOCKER"
}
