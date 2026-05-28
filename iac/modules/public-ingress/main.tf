variable "project_id" { type = string }
variable "region" { type = string }
variable "environment" { type = string }
variable "project_name" { type = string }

# Preencha para criar registro A no Cloud DNS (opcional — requer zona existente no GCP)
variable "dns_managed_zone" {
  type    = string
  default = ""
}

# Ex.: groove-staging.seudominio.com.br (FQDN completo)
variable "ingress_hostname" {
  type    = string
  default = ""
}

resource "google_compute_address" "traefik" {
  project = var.project_id
  name    = "${var.project_name}-traefik-${var.environment}"
  region  = var.region
}

resource "google_dns_record_set" "traefik" {
  count = var.dns_managed_zone != "" && var.ingress_hostname != "" ? 1 : 0

  project      = var.project_id
  managed_zone = var.dns_managed_zone
  name         = "${var.ingress_hostname}."
  type         = "A"
  ttl          = 300
  rrdatas      = [google_compute_address.traefik.address]
}

output "load_balancer_address_name" {
  description = "Nome do IP reservado — annotation do Service Traefik no GKE"
  value       = google_compute_address.traefik.name
}

output "load_balancer_ip" {
  description = "IP público do Load Balancer (Traefik)"
  value       = google_compute_address.traefik.address
}

output "ingress_hostname" {
  description = "Hostname público (Cloud DNS) ou vazio — use IP + nip.io"
  value       = var.ingress_hostname != "" ? var.ingress_hostname : "${google_compute_address.traefik.address}.nip.io"
}

output "ingress_url" {
  description = "URL HTTP para acessar o Groove"
  value       = "http://${var.ingress_hostname != "" ? var.ingress_hostname : "${google_compute_address.traefik.address}.nip.io"}"
}
