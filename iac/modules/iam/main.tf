# Wrapper do submódulo oficial workload-identity
# Ref: https://github.com/terraform-google-modules/terraform-google-kubernetes-engine/tree/master/modules/workload-identity
# Doc GCP: https://cloud.google.com/kubernetes-engine/docs/how-to/workload-identity

variable "project_id" { type = string }
variable "environment" { type = string }
variable "project_name" { type = string }
variable "kubernetes_namespace" { type = string }
variable "kubernetes_service_account" { type = string }
variable "labels" { type = map(string) }

module "workload_identity" {
  source  = "terraform-google-modules/kubernetes-engine/google//modules/workload-identity"
  version = "~> 33.1"

  project_id  = var.project_id
  name        = "${var.project_name}-app-${var.environment}"
  namespace   = var.kubernetes_namespace
  k8s_sa_name = var.kubernetes_service_account

  # Permissões mínimas para a app
  roles = [
    "roles/secretmanager.secretAccessor",
    "roles/cloudsql.client",
  ]

  use_existing_gcp_sa = false
}

output "gsa_email" {
  value = module.workload_identity.gcp_service_account_email
}

output "gsa_name" {
  value = module.workload_identity.gcp_service_account_fqn
}

output "ksa_name" {
  value = module.workload_identity.k8s_service_account_name
}
