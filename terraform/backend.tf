// Remote state config (Google Cloud Storage)
terraform {
  backend "gcs" {
    bucket = "<YOUR_TF_STATE_BUCKET>"
    prefix = "terraform/state"
  }
}
