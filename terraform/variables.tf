variable "project_id" {
  description = "Google Cloud project ID"
  type        = string
}

variable "project_number" {
  description = "Google Cloud project number (see GCP Console: IAM & Admin > Settings)"
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
  default     = "europe-west1"
}

variable "gke_name" {
  description = "GKE cluster name"
  type        = string
}

variable "network_name" {
  description = "VPC network name"
  type        = string
}

variable "subnet_name" {
  description = "Subnet name"
  type        = string
}

variable "subnet_cidr" {
  description = "Subnet CIDR range"
  type        = string
}

variable "artifact_registry_name" {
  description = "Artifact Registry repository name"
  type        = string
}

variable "proxy_subnet_cidr" {
  description = "CIDR range for proxy-only subnet (must be /23 or larger; must not overlap existing subnet; avoid 10.128.0.0/9 in auto networks)"
  type        = string
  default     = "10.10.2.0/23"
}