module "network" {
  source = "./modules/network"

  project_id          = var.project_id
  region              = var.region
  environment         = var.environment
  project_name        = var.project_name
  vpc_cidr            = var.vpc_cidr
  private_subnet_cidr = var.private_subnet_cidr
  pods_cidr           = var.pods_cidr
  services_cidr       = var.services_cidr
  use_public_nodes    = var.use_public_nodes
  labels              = local.common_labels
}

module "registry" {
  source = "./modules/registry"

  project_id                = var.project_id
  region                    = var.region
  environment               = var.environment
  project_name              = var.project_name
  labels                    = local.common_labels
  additional_reader_members = var.registry_additional_readers
}

module "secrets" {
  source = "./modules/secrets"

  project_id   = var.project_id
  environment  = var.environment
  project_name = var.project_name
  db_password  = var.db_admin_password
  labels       = local.common_labels
}

module "database" {
  source = "./modules/database"

  project_id     = var.project_id
  region         = var.region
  environment    = var.environment
  project_name   = var.project_name
  admin_password = var.db_admin_password
  tier           = var.cloud_sql_tier
  vpc_self_link  = module.network.vpc_self_link
  labels         = local.common_labels

  depends_on = [module.network]
}

module "kubernetes" {
  source = "./modules/kubernetes"

  project_id            = var.project_id
  region                = var.region
  environment           = var.environment
  project_name          = var.project_name
  network_name          = module.network.vpc_name
  subnetwork_name       = module.network.private_subnet_name
  pods_range_name       = module.network.pods_range_name
  services_range_name   = module.network.services_range_name
  node_count            = var.node_count
  machine_type          = var.machine_type
  use_preemptible_nodes = var.use_preemptible_nodes
  use_public_nodes      = var.use_public_nodes
  deletion_protection   = var.gke_deletion_protection
  labels                = local.common_labels

  depends_on = [module.network]
}

module "iam" {
  source = "./modules/iam"

  project_id                 = var.project_id
  environment                = var.environment
  project_name               = var.project_name
  kubernetes_namespace       = "dito-app"
  kubernetes_service_account = "dito-api"
  labels                     = local.common_labels

  # Workload Identity pool (PROJECT.svc.id.goog) só existe após o GKE ser criado
  depends_on = [module.kubernetes]
}

module "github_wif" {
  source = "./modules/github-wif"

  project_id                      = var.project_id
  environment                     = var.environment
  project_name                    = var.project_name
  github_owner                    = var.github_owner
  github_repo                     = var.github_repo
  labels                          = local.common_labels
  use_existing_ci_service_account = var.use_existing_ci_service_account
  manage_wif_identity_pool        = var.manage_wif_identity_pool
  existing_wif_provider           = var.existing_wif_provider
}

module "public_ingress" {
  source = "./modules/public-ingress"
  count  = var.enable_public_ingress ? 1 : 0

  project_id       = var.project_id
  region           = var.region
  environment      = var.environment
  project_name     = var.project_name
  dns_managed_zone = var.dns_managed_zone
  ingress_hostname = var.ingress_hostname
}

module "budget" {
  source = "./modules/budget"
  count  = var.enable_budget && var.billing_account_id != "" ? 1 : 0

  billing_account_id    = var.billing_account_id
  billing_account_scope = var.billing_account_scope
  project_id            = var.project_id
  environment           = var.environment
  project_name          = var.project_name
  budget_amount_brl     = var.budget_amount_brl
  budget_alert_emails   = var.budget_alert_emails
}
