variable "project_id" { type = string }
variable "environment" { type = string }
variable "project_name" { type = string }
variable "github_owner" { type = string }
variable "github_repo" { type = string }
variable "labels" { type = map(string) }

# Número do project (necessário para montar o principal set do WIF)
data "google_project" "this" {
  project_id = var.project_id
}

# ── WIF Pool ──────────────────────────────────────────────────────────────────
resource "google_iam_workload_identity_pool" "github" {
  project                   = var.project_id
  workload_identity_pool_id = "${var.project_name}-github-pool"
  display_name              = "GitHub Actions"
  description               = "Pool para autenticação keyless do GitHub Actions"
}

# ── WIF Provider (OIDC GitHub) ────────────────────────────────────────────────
resource "google_iam_workload_identity_pool_provider" "github" {
  project                            = var.project_id
  workload_identity_pool_id          = google_iam_workload_identity_pool.github.workload_identity_pool_id
  workload_identity_pool_provider_id = "github-provider"
  display_name                       = "GitHub OIDC"
  description                        = "Provider OIDC — token.actions.githubusercontent.com"

  # Mapeia claims do JWT GitHub para atributos GCP
  attribute_mapping = {
    "google.subject"       = "assertion.sub"
    "attribute.actor"      = "assertion.actor"
    "attribute.repository" = "assertion.repository"
    "attribute.ref"        = "assertion.ref"
  }

  # Restringe ao repositório exato — impede uso por outros repos
  attribute_condition = "attribute.repository == '${var.github_owner}/${var.github_repo}'"

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

# ── CI Service Account ────────────────────────────────────────────────────────
resource "google_service_account" "ci" {
  project      = var.project_id
  account_id   = "${var.project_name}-ci"
  display_name = "GitHub Actions CI — ${var.environment}"
  description  = "Terraform plan/apply e push de imagens pelo pipeline"
}

# ── IAM roles para o CI SA ────────────────────────────────────────────────────
# Roles mínimas necessárias para o Terraform gerenciar toda a infra do projeto.
# Em produção real, preferir roles customizadas ainda mais granulares.
locals {
  ci_roles = [
    "roles/compute.admin",
    "roles/container.admin",
    "roles/cloudsql.admin",
    "roles/secretmanager.admin",
    "roles/artifactregistry.admin",
    "roles/iam.serviceAccountAdmin",
    "roles/iam.workloadIdentityPoolAdmin",
    "roles/storage.admin",
    "roles/resourcemanager.projectIamAdmin",
    "roles/monitoring.editor",
    "roles/billing.viewer",
  ]
}

resource "google_project_iam_member" "ci" {
  for_each = toset(local.ci_roles)
  project  = var.project_id
  role     = each.value
  member   = "serviceAccount:${google_service_account.ci.email}"
}

# ── Binding WIF → CI SA ───────────────────────────────────────────────────────
# Permite que tokens emitidos pelo pool para o repo específico
# se comportem como o CI SA (sem chave JSON).
resource "google_service_account_iam_member" "wif_binding" {
  service_account_id = google_service_account.ci.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/attribute.repository/${var.github_owner}/${var.github_repo}"
}

# ── Outputs (copiar para GitHub Secrets) ─────────────────────────────────────
output "workload_identity_provider" {
  description = "→ GitHub Secret: GCP_WORKLOAD_IDENTITY_PROVIDER"
  value       = google_iam_workload_identity_pool_provider.github.name
}

output "service_account_email" {
  description = "→ GitHub Secret: GCP_SERVICE_ACCOUNT"
  value       = google_service_account.ci.email
}

output "pool_name" {
  description = "Nome do WIF pool"
  value       = google_iam_workload_identity_pool.github.name
}
