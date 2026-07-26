terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 7.22, < 8.0" # 对齐 sql-db 28.1 要求
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = ">= 7.22, < 8.0" # sql-db 模块部分资源走 google-beta
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

# sql-db 模块内部使用 google-beta,显式配置避免 beta 资源缺省 project/region。
provider "google-beta" {
  project = var.project_id
  region  = var.region
}
