# Wrapper do módulo oficial terraform-google-modules/network
# Ref: https://registry.terraform.io/modules/terraform-google-modules/network/google
# Doc GCP: https://cloud.google.com/vpc/docs/terraform

variable "project_id" { type = string }
variable "region" { type = string }
variable "environment" { type = string }
variable "project_name" { type = string }
variable "vpc_cidr" { type = string }
variable "private_subnet_cidr" { type = string }
variable "pods_cidr" { type = string }
variable "services_cidr" { type = string }
variable "use_public_nodes" { type = bool }
variable "labels" { type = map(string) }

locals {
  subnet_name         = "${var.project_name}-private-${var.environment}"
  pods_range_name     = "${var.project_name}-pods-${var.environment}"
  services_range_name = "${var.project_name}-services-${var.environment}"
}

resource "google_project_service" "servicenetworking" {
  project = var.project_id
  service = "servicenetworking.googleapis.com"

  disable_on_destroy = false
}

module "vpc" {
  source  = "terraform-google-modules/network/google"
  version = "~> 10.0"

  project_id   = var.project_id
  network_name = "${var.project_name}-vpc-${var.environment}"
  routing_mode = "REGIONAL"

  subnets = [
    {
      subnet_name           = local.subnet_name
      subnet_ip             = var.private_subnet_cidr
      subnet_region         = var.region
      subnet_private_access = true
      subnet_flow_logs      = false # cost-aware: flow logs desligados em trial
    },
  ]

  secondary_ranges = {
    (local.subnet_name) = [
      {
        range_name    = local.pods_range_name
        ip_cidr_range = var.pods_cidr
      },
      {
        range_name    = local.services_range_name
        ip_cidr_range = var.services_cidr
      },
    ]
  }

  firewall_rules = [
    {
      name        = "${var.project_name}-allow-internal-${var.environment}"
      description = "Tráfego interno VPC + pods + services"
      direction   = "INGRESS"
      ranges      = [var.vpc_cidr, var.pods_cidr, var.services_cidr]
      allow = [
        { protocol = "tcp", ports = ["0-65535"] },
        { protocol = "udp", ports = ["0-65535"] },
        { protocol = "icmp" },
      ]
    },
    {
      name        = "${var.project_name}-allow-health-${var.environment}"
      description = "GCP health checks para GKE"
      direction   = "INGRESS"
      ranges      = ["130.211.0.0/22", "35.191.0.0/16"]
      target_tags = ["gke-node"]
      allow = [
        { protocol = "tcp", ports = ["8080"] },
      ]
    },
  ]
}

# Private Service Access — Cloud SQL private IP
# Ref: https://cloud.google.com/sql/docs/postgres/configure-private-ip
resource "google_compute_global_address" "private_service_range" {
  name          = "${var.project_name}-psa-${var.environment}"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = module.vpc.network_id
}

resource "google_service_networking_connection" "private_vpc_connection" {
  network                 = module.vpc.network_id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_service_range.name]

  depends_on = [google_project_service.servicenetworking]

  timeouts {
    create = "20m"
    update = "20m"
  }
}

# Cloud NAT — módulo oficial cloud-router
# Ref: https://registry.terraform.io/modules/terraform-google-modules/cloud-router/google
module "cloud_router" {
  count   = var.use_public_nodes ? 0 : 1
  source  = "terraform-google-modules/cloud-router/google"
  version = "~> 6.0"

  name    = "${var.project_name}-router-${var.environment}"
  project = var.project_id
  region  = var.region
  network = module.vpc.network_name

  bgp = {
    asn = 64514
  }

  nats = [{
    name                               = "${var.project_name}-nat-${var.environment}"
    source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
    nat_ip_allocate_option             = "AUTO_ONLY"
    log_config = {
      enable = var.environment == "production"
      filter = "ERRORS_ONLY"
    }
  }]
}

output "vpc_id" {
  value = module.vpc.network_id
}

output "vpc_name" {
  value = module.vpc.network_name
}

output "vpc_self_link" {
  value = module.vpc.network_self_link
}

output "private_subnet_name" {
  value = local.subnet_name
}

output "private_subnet_id" {
  value = module.vpc.subnets["${var.region}/${local.subnet_name}"].id
}

output "pods_range_name" {
  value = local.pods_range_name
}

output "services_range_name" {
  value = local.services_range_name
}

output "nat_enabled" {
  value = !var.use_public_nodes
}
