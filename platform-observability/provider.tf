terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 6.38, < 8.0" # 仅用 google_monitoring_* 原生资源,无模块依赖,版本宽松
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}
