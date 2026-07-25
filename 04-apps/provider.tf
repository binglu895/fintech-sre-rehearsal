terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project = "kqeardr-gcp-shimano-internal"
  region  = "asia-northeast1"
}
