variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "Região GCP (southamerica-east1 = São Paulo)"
  type        = string
  default     = "southamerica-east1"
}

variable "environment" {
  description = "Ambiente (staging | production)"
  type        = string

  validation {
    condition     = contains(["staging", "production"], var.environment)
    error_message = "environment deve ser staging ou production."
  }
}

variable "project_name" {
  description = "Prefixo de nomes de recursos"
  type        = string
  default     = "dito"
}

variable "vpc_cidr" {
  description = "CIDR da VPC"
  type        = string
}

variable "private_subnet_cidr" {
  description = "CIDR da subnet privada (nodes GKE)"
  type        = string
}

variable "pods_cidr" {
  description = "Secondary range — pods GKE"
  type        = string
  default     = "10.1.0.0/16"
}

variable "services_cidr" {
  description = "Secondary range — services GKE"
  type        = string
  default     = "10.2.0.0/20"
}

variable "db_admin_password" {
  description = "Senha admin Cloud SQL"
  type        = string
  sensitive   = true
}

variable "node_count" {
  description = "Número de nodes GKE"
  type        = number
}

variable "machine_type" {
  description = "Machine type dos nodes (e2-small = mais barato)"
  type        = string
  default     = "e2-small"
}

variable "use_preemptible_nodes" {
  description = "Usar nodes preemptíveis (~70% mais barato) — staging recomendado"
  type        = bool
  default     = true
}

variable "use_public_nodes" {
  description = "Nodes com IP público — evita Cloud NAT ($$$). Apenas staging/dev."
  type        = bool
  default     = false
}

variable "cloud_sql_tier" {
  description = "Tier Cloud SQL (db-f1-micro = mais barato)"
  type        = string
  default     = "db-f1-micro"
}

variable "billing_account_id" {
  description = "Billing Account ID para alertas de orçamento (012345-678901-ABCDEF)"
  type        = string
  default     = ""
}

variable "billing_account_scope" {
  description = "Orçamento cobre billing account inteira (2 projects compartilham R$ 1.700)"
  type        = bool
  default     = false
}

variable "budget_amount_brl" {
  description = "Limite do orçamento em BRL (créditos trial)"
  type        = number
  default     = 1700
}

variable "budget_alert_emails" {
  description = "E-mails para alertas de billing"
  type        = list(string)
  default     = []
}

variable "enable_budget" {
  description = "Criar Billing Budget via Terraform"
  type        = bool
  default     = true
}

variable "labels" {
  description = "Labels GCP aplicadas aos recursos"
  type        = map(string)
  default     = {}
}

variable "github_owner" {
  description = "Owner/organização do repositório GitHub (para WIF)"
  type        = string
  default     = "nikolastsdev"
}

variable "github_repo" {
  description = "Nome do repositório GitHub (para WIF)"
  type        = string
  default     = "dito-devops-challenge"
}

variable "use_existing_ci_service_account" {
  description = "Usa SA dito-ci já criada manualmente no GCP"
  type        = bool
  default     = false
}

variable "manage_wif_identity_pool" {
  description = "Cria pool/provider WIF via Terraform"
  type        = bool
  default     = true
}

variable "existing_wif_provider" {
  description = "Provider WIF existente (quando manage_wif_identity_pool=false)"
  type        = string
  default     = ""
}

variable "enable_public_ingress" {
  description = "Reservar IP estático regional para Traefik Load Balancer"
  type        = bool
  default     = true
}

variable "ingress_hostname" {
  description = "FQDN público (ex.: groove-staging.seudominio.com.br) — vazio = usar IP.nip.io"
  type        = string
  default     = ""
}

variable "dns_managed_zone" {
  description = "Nome da zona Cloud DNS no GCP (opcional)"
  type        = string
  default     = ""
}

variable "gke_deletion_protection" {
  description = "Override da proteção contra destroy do GKE (null = true só em production)"
  type        = bool
  default     = null
}
