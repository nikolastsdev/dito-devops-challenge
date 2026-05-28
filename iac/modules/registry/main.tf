variable "project_id" { type = string }
variable "region" { type = string }
variable "environment" { type = string }
variable "project_name" { type = string }
variable "labels" { type = map(string) }

resource "google_artifact_registry_repository" "main" {
  location      = var.region
  repository_id = "${var.project_name}-api-${var.environment}"
  description   = "Container images — Desafio DevOps Dito"
  format        = "DOCKER"

  labels = var.labels
}

output "repository_id" {
  value = google_artifact_registry_repository.main.repository_id
}

output "repository_url" {
  value = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.main.repository_id}"
}

output "docker_image_path" {
  value = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.main.repository_id}/dito-api"
}
