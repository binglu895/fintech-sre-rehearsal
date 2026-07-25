terraform {
  backend "gcs" {
    bucket = "fintech-iac-states-prod"
    prefix = "ledger-db/state"
  }
}
