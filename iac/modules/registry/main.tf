variable "project_id" { type = string }
variable "region" { type = string }
variable "environment" { type = string }
variable "project_name" { type = string }
variable "labels" { type = map(string) }

variable "additional_reader_members" {
  description = "Membros IAM extras com acesso de leitura ao registry (ex.: SA de outro projeto para image promotion)"
  type        = list(string)
  default     = []
}

resource "google_artifact_registry_repository" "main" {
  location      = var.region
  repository_id = "${var.project_name}-api-${var.environment}"
  description   = "Container images — Desafio DevOps Dito"
  format        = "DOCKER"

  labels = var.labels
}

# Acesso cross-project para promoção de imagem (ex.: SA de production lê o
# registry de staging para copiar o mesmo digest sem rebuild).
# IAM members aceitam SAs ainda não criadas, então é seguro aplicar antes.
resource "google_artifact_registry_repository_iam_member" "additional_readers" {
  for_each = toset(var.additional_reader_members)

  project    = var.project_id
  location   = google_artifact_registry_repository.main.location
  repository = google_artifact_registry_repository.main.name
  role       = "roles/artifactregistry.reader"
  member     = each.value
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
