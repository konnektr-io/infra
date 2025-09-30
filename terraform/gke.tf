// GKE cluster resources
resource "google_container_cluster" "primary" {
  name               = var.gke_name
  location           = var.region
  network            = var.network_name
  initial_node_count = 1

  node_config {
    machine_type = var.node_machine_type
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
  }
}
