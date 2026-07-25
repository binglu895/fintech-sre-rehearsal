terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 6.28, < 7.0"
    }
  }
}

provider "google" {
  project = "kqeardr-gcp-shimano-internal"
  region  = "asia-northeast1"
}
