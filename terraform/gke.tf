// GKE node pool service account (least privilege)
resource "google_service_account" "gke_nodes" {
  account_id   = "gke-nodes"
  display_name = "GKE Node Pool Service Account"
}

// IAM roles for GKE node pool service account
resource "google_project_iam_member" "gke_nodes_container_node_sa" {
  project = var.project_id
  role    = "roles/container.nodeServiceAccount"
  member  = "serviceAccount:${google_service_account.gke_nodes.email}"
}

resource "google_project_iam_member" "gke_nodes_storage_object_viewer" {
  project = var.project_id
  role    = "roles/storage.objectViewer"
  member  = "serviceAccount:${google_service_account.gke_nodes.email}"
}

// GKE cluster resources (cost-optimized, spot/preemptible only)
resource "google_container_cluster" "primary" {
  name       = var.gke_name
  location   = var.region
  network    = var.network_name
  subnetwork = var.subnet_name

  enable_autopilot = true

  datapath_provider = "ADVANCED_DATAPATH" # Enables Dataplane V2 (Cilium)

  # Use custom node pool service account for Autopilot
  cluster_autoscaling {
    auto_provisioning_defaults {
      service_account = google_service_account.gke_nodes.email
    }
  }

  # Disable expensive features
  logging_service             = "none"
  monitoring_service          = "none"
  enable_tpu                  = false
  # Enable private cluster for security/cost
  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false
    master_ipv4_cidr_block  = "172.16.0.0/28"
  }
  ip_allocation_policy {}
}
