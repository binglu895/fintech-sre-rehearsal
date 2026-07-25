terraform {
  backend "gcs" {
    bucket = "fintech-iac-states-prod"
    prefix = "gke-platform/state"
  }
}
