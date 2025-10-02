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
  name     = var.gke_name
  location = var.region
  network  = var.network_name
  subnetwork = var.subnet_name

  remove_default_node_pool = true
  initial_node_count = 1

  # Disable expensive features
  logging_service    = "none"
  monitoring_service = "none"
  enable_intranode_visibility = false
  enable_shielded_nodes = false
  enable_tpu = false
  # Enable private cluster for security/cost
  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false
    master_ipv4_cidr_block  = "172.16.0.0/28"
  }
  ip_allocation_policy {}
}

resource "google_container_node_pool" "spot_pool" {
  name       = "spot-pool"
  cluster    = google_container_cluster.primary.name
  location   = var.region


  autoscaling {
    min_node_count = var.min_node_count
    max_node_count = var.max_node_count
  }

  node_config {
    preemptible    = true
    spot           = true
    machine_type   = var.node_machine_type
    service_account = google_service_account.gke_nodes.email
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
    labels = {
      "cloud.google.com/gke-spot" = "true"
    }
    metadata = {
      disable-legacy-endpoints = "true"
    }
    tags = ["gke-node", "spot"]
  }

  management {
    auto_repair  = false
    auto_upgrade = true
  }
}

