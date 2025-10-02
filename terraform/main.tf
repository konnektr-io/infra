// Entry point for Terraform configuration
terraform {
  required_version = ">= 1.3.0"
  backend "gcs" {}
}

provider "google" {
  project = var.project_id
  region  = var.region
}

// All resources are loaded from .tf files in this directory
