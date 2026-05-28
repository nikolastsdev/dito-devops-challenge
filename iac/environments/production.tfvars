# =============================================================================
# PRODUCTION — Project: dito-production
# =============================================================================

project_id = "dito-production"

environment         = "production"
region              = "southamerica-east1"
vpc_cidr            = "10.20.0.0/16"
private_subnet_cidr = "10.20.0.0/24"
pods_cidr           = "10.21.0.0/16"
services_cidr       = "10.22.0.0/20"

# Diferenças vs staging (fluxo GitOps production)
node_count            = 2
machine_type          = "e2-small"
use_preemptible_nodes = true # preemptible no trial — economia
use_public_nodes      = false # nodes privados + Cloud NAT

cloud_sql_tier = "db-f1-micro"

billing_account_id    = "01817D-297FE7-229CDF"
budget_amount_brl     = 1700
budget_alert_emails   = ["nikolas.t.s.dev@gmail.com"]
enable_budget         = false # budget único criado pelo apply staging
billing_account_scope = false

enable_public_ingress = true
ingress_hostname      = ""
dns_managed_zone      = ""

github_owner = "nikolastsdev"
github_repo  = "dito-devops-challenge"

labels = {
  owner       = "nikolastsdev"
  challenge   = "dito-devops-iii"
  environment = "production"
}
