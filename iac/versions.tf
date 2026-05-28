terraform {
  required_version = ">= 1.5.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 6.47.0, < 7.0.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = ">= 6.47.0, < 7.0.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.0"
    }
  }
}

# Versões dos módulos oficiais Google (terraform-google-modules)
# Ref: https://cloud.google.com/docs/terraform/blueprints/terraform-blueprints
locals {
  tf_google_network_version      = "~> 10.0"
  tf_google_gke_version          = "~> 35.1"
  tf_google_cloud_router_version = "~> 6.0"
  tf_google_sql_db_version       = "~> 25.2"
}
