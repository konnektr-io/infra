// Shared outputs
output "gke_cluster_name" {
  value = google_container_cluster.primary.name
}

output "network_name" {
  value = google_compute_network.vpc_network.name
}

output "artifact_registry_repo_url" {
  value = google_artifact_registry_repository.docker_repo.repository_url
}

output "nat_router_name" {
  value = google_compute_router.nat_router.name
}

output "nat_name" {
  value = google_compute_router_nat.nat_gke.name
}

output "gke_node_service_account_email" {
  value = google_service_account.gke_nodes.email
}
