terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 6.28, < 7.0"
    }
  }
}

# project/region 由变量注入(各环境不同),不再写死。
provider "google" {
  project = var.project_id
  region  = var.region
}
