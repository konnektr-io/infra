// Shared variables
variable "project_id" {
  description = "Google Cloud project ID"
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

variable "node_machine_type" {
  description = "GKE node machine type"
  type        = string
  default     = "e2-medium"
}

variable "node_count" {
  description = "Number of nodes in the spot node pool"
  type        = number
  default     = 3
}

variable "min_node_count" {
  description = "Minimum number of nodes for autoscaling"
  type        = number
  default     = 1
}

variable "max_node_count" {
  description = "Maximum number of nodes for autoscaling"
  type        = number
  default     = 5
}

variable "artifact_registry_name" {
  description = "Artifact Registry repository name"
  type        = string
  default     = "konnektr-docker"
}