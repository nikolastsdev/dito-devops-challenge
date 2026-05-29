# =============================================================================
# STAGING — Project: dito-staging
# =============================================================================
# Isolamento total via GCP Project separado (mesma billing account / créditos)
# Perfil: cost-optimized trial

project_id = "dito-staging"

environment         = "staging"
region              = "southamerica-east1"
vpc_cidr            = "10.10.0.0/16"
private_subnet_cidr = "10.10.0.0/24"
pods_cidr           = "10.11.0.0/16"
services_cidr       = "10.12.0.0/20"

node_count            = 1
machine_type          = "e2-medium" # 4 GB RAM — mínimo confortável com ArgoCD + ESO + app
use_preemptible_nodes = true
use_public_nodes      = false # nodes privados + Cloud NAT (exigência do desafio)

cloud_sql_tier = "db-f1-micro"

billing_account_id    = "01817D-297FE7-229CDF"
budget_amount_brl     = 1700
budget_alert_emails   = ["nikolas.t.s.dev@gmail.com"]
enable_budget         = false # budget criado manualmente no 
billing_account_scope = true

enable_public_ingress = true
ingress_hostname      = "" # ex.: groove-staging.seudominio.com.br
dns_managed_zone      = "" # ex.: seudominio-com-br (zona no Cloud DNS)

github_owner = "nikolastsdev"
github_repo  = "dito-devops-challenge"

# WIF/SA criados manualmente no Console antes do primeiro apply
use_existing_ci_service_account = true
manage_wif_identity_pool        = false
existing_wif_provider           = "projects/747897055808/locations/global/workloadIdentityPools/github-pool/providers/github"

# Image promotion: a SA CI de production lê o registry de staging para copiar
# o mesmo digest (sem rebuild) durante o app-promote.yml.
registry_additional_readers = [
  "serviceAccount:dito-ci@dito-production.iam.gserviceaccount.com",
]

labels = {
  owner       = "nikolastsdev"
  challenge   = "dito-devops-iii"
  environment = "staging"
}
