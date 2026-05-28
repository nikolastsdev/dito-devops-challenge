locals {
  common_labels = merge(var.labels, {
    project     = var.project_name
    environment = var.environment
    managed_by  = "terraform"
  })

  name_prefix = "${var.project_name}-${var.environment}"
}
