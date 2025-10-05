// Remote state config (Google Cloud Storage)
terraform {
  backend "gcs" {
    bucket = "konnektr-tfstate"
    prefix = "terraform/state"
  }
}
