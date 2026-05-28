# Wrapper do módulo oficial terraform-google-modules/sql-db (postgresql)
# Ref: https://registry.terraform.io/modules/terraform-google-modules/sql-db/google
# Doc GCP: https://cloud.google.com/sql/docs/postgres/create-instance

variable "project_id" { type = string }
variable "region" { type = string }
variable "environment" { type = string }
variable "project_name" { type = string }
variable "admin_password" {
  type      = string
  sensitive = true
}
variable "tier" { type = string }
variable "vpc_self_link" { type = string }
variable "labels" { type = map(string) }

module "postgresql" {
  source  = "terraform-google-modules/sql-db/google//modules/postgresql"
  version = "~> 25.2"

  project_id       = var.project_id
  name             = "${var.project_name}-pg-${var.environment}"
  database_version = "POSTGRES_15"
  region           = var.region
  zone             = "${var.region}-a"
  tier             = var.tier

  availability_type = var.environment == "production" ? "REGIONAL" : "ZONAL"
  disk_size         = 10
  disk_type         = "PD_HDD"
  disk_autoresize   = true

  ip_configuration = {
    ipv4_enabled    = false
    private_network = var.vpc_self_link
  }

  db_name       = "dito_app"
  user_name     = "dito_app"
  user_password = var.admin_password

  backup_configuration = {
    enabled                        = true
    point_in_time_recovery_enabled = var.environment == "production"
    start_time                     = "04:00"
  }

  deletion_protection = var.environment == "production"

  user_labels = var.labels
}

output "instance_name" {
  value = module.postgresql.instance_name
}

output "connection_name" {
  value = module.postgresql.instance_connection_name
}

output "private_ip_address" {
  value = module.postgresql.private_ip_address
}
