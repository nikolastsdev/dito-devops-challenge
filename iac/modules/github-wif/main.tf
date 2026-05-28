variable "project_id" { type = string }
variable "environment" { type = string }
variable "project_name" { type = string }
variable "github_owner" { type = string }
variable "github_repo" { type = string }
variable "labels" { type = map(string) }

variable "use_existing_ci_service_account" {
  description = "Usa SA CI já criada manualmente (evita erro 409)"
  type        = bool
  default     = false
}

variable "manage_wif_identity_pool" {
  description = "Cria pool/provider WIF via Terraform. Desligue se já configurou no Console."
  type        = bool
  default     = true
}

variable "existing_wif_provider" {
  description = "Resource name do provider WIF existente (quando manage_wif_identity_pool=false)"
  type        = string
  default     = ""
}

data "google_project" "this" {
  project_id = var.project_id
}

resource "google_service_account" "ci" {
  count = var.use_existing_ci_service_account ? 0 : 1

  project      = var.project_id
  account_id   = "${var.project_name}-ci"
  display_name = "GitHub Actions CI — ${var.environment}"
  description  = "Terraform plan/apply e push de imagens pelo pipeline"
}

data "google_service_account" "ci" {
  count = var.use_existing_ci_service_account ? 1 : 0

  account_id = "${var.project_name}-ci"
  project    = var.project_id
}

locals {
  ci_email = var.use_existing_ci_service_account ? data.google_service_account.ci[0].email : google_service_account.ci[0].email
  ci_name  = var.use_existing_ci_service_account ? data.google_service_account.ci[0].name : google_service_account.ci[0].name
}

resource "google_iam_workload_identity_pool" "github" {
  count = var.manage_wif_identity_pool ? 1 : 0

  project                   = var.project_id
  workload_identity_pool_id = "${var.project_name}-github-pool"
  display_name              = "GitHub Actions"
  description               = "Pool para autenticação keyless do GitHub Actions"
}

resource "google_iam_workload_identity_pool_provider" "github" {
  count = var.manage_wif_identity_pool ? 1 : 0

  project                            = var.project_id
  workload_identity_pool_id          = google_iam_workload_identity_pool.github[0].workload_identity_pool_id
  workload_identity_pool_provider_id = "github-provider"
  display_name                       = "GitHub OIDC"
  description                        = "Provider OIDC — token.actions.githubusercontent.com"

  attribute_mapping = {
    "google.subject"       = "assertion.sub"
    "attribute.actor"      = "assertion.actor"
    "attribute.repository" = "assertion.repository"
    "attribute.ref"        = "assertion.ref"
  }

  attribute_condition = "attribute.repository == '${var.github_owner}/${var.github_repo}'"

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

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
    "roles/servicenetworking.networksAdmin",
  ]
}

resource "google_project_iam_member" "ci" {
  for_each = toset(local.ci_roles)

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${local.ci_email}"
}

resource "google_service_account_iam_member" "wif_binding" {
  count = var.manage_wif_identity_pool ? 1 : 0

  service_account_id = local.ci_name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github[0].name}/attribute.repository/${var.github_owner}/${var.github_repo}"
}

output "workload_identity_provider" {
  description = "→ GitHub Secret: GCP_WORKLOAD_IDENTITY_PROVIDER"
  value       = var.manage_wif_identity_pool ? google_iam_workload_identity_pool_provider.github[0].name : var.existing_wif_provider
}

output "service_account_email" {
  description = "→ GitHub Secret: GCP_SERVICE_ACCOUNT"
  value       = local.ci_email
}

output "pool_name" {
  description = "Nome do WIF pool"
  value       = var.manage_wif_identity_pool ? google_iam_workload_identity_pool.github[0].name : null
}
