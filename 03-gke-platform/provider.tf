terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
  }
}

provider "google" {
  project = "kqeardr-gcp-shimano-internal"
  region  = "asia-northeast1"
}

# private-cluster 模块的 K8s 资源需要 kubernetes provider。
# 用集群凭证动态配置(集群建好后由 module 输出驱动)。
data "google_client_config" "default" {}

provider "kubernetes" {
  host                   = "https://${module.gke.endpoint}"
  token                  = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode(module.gke.ca_certificate)
}
