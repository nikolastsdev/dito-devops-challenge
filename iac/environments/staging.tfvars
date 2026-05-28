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
enable_budget         = false # budget criado manualmente no Console
billing_account_scope = true

enable_public_ingress = true
ingress_hostname      = "" # ex.: groove-staging.seudominio.com.br
dns_managed_zone      = "" # ex.: seudominio-com-br (zona no Cloud DNS)

github_owner = "nikolasschaffer"
github_repo  = "dito-devops-challenge"

labels = {
  owner       = "nikolasschafer"
  challenge   = "dito-devops-iii"
  environment = "staging"
}
