variable "project_id" { type = string }
variable "environment" { type = string }
variable "project_name" { type = string }
variable "db_password" {
  type      = string
  sensitive = true
}
variable "labels" { type = map(string) }

resource "google_secret_manager_secret" "db_password" {
  secret_id = "${var.project_name}-db-password-${var.environment}"

  replication {
    auto {}
  }

  labels = var.labels
}

resource "google_secret_manager_secret_version" "db_password" {
  secret      = google_secret_manager_secret.db_password.id
  secret_data = var.db_password
}

output "db_password_secret_id" {
  value = google_secret_manager_secret.db_password.secret_id
}

output "db_password_secret_name" {
  value = google_secret_manager_secret.db_password.name
}
