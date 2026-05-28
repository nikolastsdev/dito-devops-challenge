variable "project_id" { type = string }
variable "region" { type = string }
variable "environment" { type = string }
variable "project_name" { type = string }
variable "labels" { type = map(string) }

resource "google_storage_bucket" "terraform_state" {
  name          = "${var.project_id}-tfstate"
  location      = var.region
  force_destroy = false

  uniform_bucket_level_access = true

  versioning {
    enabled = true
  }

  lifecycle_rule {
    condition {
      num_newer_versions = 5
    }
    action {
      type = "Delete"
    }
  }

  labels = var.labels
}

output "bucket_name" {
  value = google_storage_bucket.terraform_state.name
}

output "bucket_url" {
  value = google_storage_bucket.terraform_state.url
}
