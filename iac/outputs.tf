output "environment" {
  description = "Ambiente provisionado"
  value       = var.environment
}

output "project_id" {
  description = "GCP Project ID"
  value       = var.project_id
}

output "vpc_name" {
  description = "Nome da VPC"
  value       = module.network.vpc_name
}

output "gke_cluster_name" {
  description = "Nome do cluster GKE"
  value       = module.kubernetes.cluster_name
}

output "gke_cluster_location" {
  description = "Localização do cluster"
  value       = module.kubernetes.cluster_location
}

output "get_credentials_command" {
  description = "Comando para obter kubeconfig"
  value       = module.kubernetes.get_credentials_command
}

output "cloud_sql_connection_name" {
  description = "Connection name Cloud SQL (proxy)"
  value       = module.database.connection_name
}

output "cloud_sql_private_ip" {
  description = "IP privado Cloud SQL"
  value       = module.database.private_ip_address
}

output "secret_manager_db_password_id" {
  description = "ID do secret db_password no Secret Manager"
  value       = module.secrets.db_password_secret_id
}

output "artifact_registry_url" {
  description = "URL base Artifact Registry"
  value       = module.registry.repository_url
}

output "docker_image_path" {
  description = "Caminho completo da imagem Docker"
  value       = module.registry.docker_image_path
}

output "tfstate_bucket" {
  description = "Bucket GCS para Terraform state (criado pelo bootstrap)"
  value       = "${var.project_id}-tfstate"
}

output "workload_service_account" {
  description = "Service Account GKE Workload Identity (app pods)"
  value       = module.iam.gsa_email
}

output "traefik_load_balancer_ip" {
  description = "IP público do Traefik (Load Balancer GCP)"
  value       = var.enable_public_ingress ? module.public_ingress[0].load_balancer_ip : null
}

output "traefik_load_balancer_address_name" {
  description = "Nome do IP reservado — usado na annotation do Service Traefik"
  value       = var.enable_public_ingress ? module.public_ingress[0].load_balancer_address_name : null
}

output "groove_public_url" {
  description = "URL HTTP pública do app Groove (via Traefik)"
  value       = var.enable_public_ingress ? module.public_ingress[0].ingress_url : null
}

# ── GitHub Actions WIF — copiar para GitHub Secrets após o primeiro apply ─────
output "github_wif_provider" {
  description = "→ GitHub Secret: GCP_WORKLOAD_IDENTITY_PROVIDER"
  value       = module.github_wif.workload_identity_provider
}

output "github_ci_sa_email" {
  description = "→ GitHub Secret: GCP_SERVICE_ACCOUNT"
  value       = module.github_wif.service_account_email
}

output "setup_github_secrets_commands" {
  description = "Comandos para configurar secrets no GitHub Environment (staging ou production)"
  value       = <<-EOT
    gh api repos/${var.github_owner}/${var.github_repo}/environments/${var.environment} -X PUT

    gh secret set GCP_WORKLOAD_IDENTITY_PROVIDER \
      --env ${var.environment} \
      --body "${module.github_wif.workload_identity_provider}" \
      --repo ${var.github_owner}/${var.github_repo}

    gh secret set GCP_SERVICE_ACCOUNT \
      --env ${var.environment} \
      --body "${module.github_wif.service_account_email}" \
      --repo ${var.github_owner}/${var.github_repo}

    gh secret set TF_VAR_DB_ADMIN_PASSWORD \
      --env ${var.environment} \
      --body "SUA_SENHA_AQUI" \
      --repo ${var.github_owner}/${var.github_repo}

    gh variable set GCP_PROJECT_ID_${upper(var.environment)} \
      --body "${var.project_id}" \
      --repo ${var.github_owner}/${var.github_repo}
  EOT
}

output "estimated_monthly_cost_brl" {
  description = "Estimativa mensal (referência docs/runbook/budget-and-costs.md)"
  value = {
    gke_nodes         = var.use_preemptible_nodes ? "~R$ 80-150 (preemptible e2-small)" : "~R$ 250-400"
    cloud_nat         = var.use_public_nodes ? "R$ 0 (desabilitado)" : "~R$ 150-220"
    cloud_sql         = var.cloud_sql_tier == "db-f1-micro" ? "~R$ 40-60" : "~R$ 150+"
    gke_management    = "~R$ 0 (1 cluster zonal free tier)"
    secret_manager    = "~R$ 1-5"
    artifact_registry = "~R$ 5-15"
    total_estimate    = var.use_public_nodes ? "~R$ 130-230/mês staging" : "~R$ 280-450/mês staging"
  }
}
