// Proxy-only subnet for regional external Application Load Balancer
// Required for regional external Gateway (gke-l7-regional-external-managed)
resource "google_compute_subnetwork" "proxy_only_subnet" {
  name          = "${var.network_name}-proxy-only"
  ip_cidr_range = var.proxy_subnet_cidr # Must be /23 or larger; avoid 10.128.0.0/9 in auto mode networks
  region        = var.region
  network       = google_compute_network.vpc_network.id
  purpose       = "REGIONAL_MANAGED_PROXY"
  role          = "ACTIVE"
}

// Static IP address for regional external Gateway
resource "google_compute_address" "gateway_external_ip" {
  name         = "gateway-external-ip"
  region       = var.region
  network_tier = "STANDARD" # Regional IP uses STANDARD tier
}

// Output the static IP for use in Gateway configuration
output "gateway_external_ip" {
  description = "Static IP address for the regional external Gateway"
  value       = google_compute_address.gateway_external_ip.address
}
