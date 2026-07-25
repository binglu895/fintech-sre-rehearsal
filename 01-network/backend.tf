terraform {
  backend "gcs" {
    bucket = "fintech-iac-states-prod"
    prefix = "network/state"
  }
}
