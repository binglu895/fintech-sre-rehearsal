terraform {
  backend "gcs" {
    bucket = "fintech-iac-states-prod"
    prefix = "apps/state"
  }
}
