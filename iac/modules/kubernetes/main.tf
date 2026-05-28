# Wrapper do módulo oficial terraform-google-modules/kubernetes-engine (private-cluster)
# Ref: https://registry.terraform.io/modules/terraform-google-modules/kubernetes-engine/google
# Doc GCP: https://cloud.google.com/kubernetes-engine/docs/terraform

variable "project_id" { type = string }
variable "region" { type = string }
variable "environment" { type = string }
variable "project_name" { type = string }
variable "network_name" { type = string }
variable "subnetwork_name" { type = string }
variable "pods_range_name" { type = string }
variable "services_range_name" { type = string }
variable "node_count" { type = number }
variable "machine_type" { type = string }
variable "use_preemptible_nodes" { type = bool }
variable "use_public_nodes" { type = bool }
variable "labels" { type = map(string) }

module "gke" {
  source  = "terraform-google-modules/kubernetes-engine/google//modules/private-cluster"
  version = "~> 33.1"

  project_id = var.project_id
  name       = "${var.project_name}-gke-${var.environment}"
  regional   = true
  region     = var.region

  network    = var.network_name
  subnetwork = var.subnetwork_name

  ip_range_pods     = var.pods_range_name
  ip_range_services = var.services_range_name

  # Doc: https://cloud.google.com/kubernetes-engine/docs/how-to/private-clusters
  enable_private_nodes    = !var.use_public_nodes
  enable_private_endpoint = false
  master_ipv4_cidr_block  = "172.16.0.0/28"

  # Workload Identity — https://cloud.google.com/kubernetes-engine/docs/how-to/workload-identity
  identity_namespace = "${var.project_id}.svc.id.goog"

  release_channel = "REGULAR"

  # Staging pode ser destruído via pipeline; production fica protegido
  deletion_protection = var.environment == "production"

  remove_default_node_pool = true

  node_pools = [
    {
      name         = "${var.project_name}-pool-${var.environment}"
      machine_type = var.machine_type
      min_count    = var.node_count
      max_count    = var.node_count
      auto_repair  = true
      auto_upgrade = true
      preemptible  = var.use_preemptible_nodes
      disk_size_gb = 30
      disk_type    = "pd-standard"
    },
  ]

  node_pools_oauth_scopes = {
    all = ["https://www.googleapis.com/auth/cloud-platform"]
  }

  node_pools_labels = {
    all = merge(var.labels, { node-pool = "primary" })
  }

  node_pools_tags = {
    all = ["gke-node"]
  }

  cluster_resource_labels = var.labels
}

output "cluster_name" {
  value = module.gke.name
}

output "cluster_location" {
  value = module.gke.location
}

output "cluster_endpoint" {
  value     = module.gke.endpoint
  sensitive = true
}

output "workload_identity_pool" {
  value = module.gke.identity_namespace
}

output "get_credentials_command" {
  value = "gcloud container clusters get-credentials ${module.gke.name} --region ${var.region} --project ${var.project_id}"
}
