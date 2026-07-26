terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 6.38, < 8.0" # 应用层暂无模块约束,给一个现代基线
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}
