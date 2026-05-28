# Backend remoto — Google Cloud Storage (1 bucket por GCP Project)
#
# Cada ambiente usa seu próprio project e bucket de state:
#   staging    → gs://dito-challenge-staging-tfstate
#   production → gs://dito-challenge-production-tfstate
#
# Bootstrap cria os buckets: scripts/bootstrap-gcp-projects.sh
#
# Init por ambiente:
#   terraform init -backend-config=backends/staging.gcs.tfbackend -reconfigure
#   terraform init -backend-config=backends/production.gcs.tfbackend -reconfigure
#
# Ou use: ./scripts/tf-apply.sh staging apply

terraform {
  backend "gcs" {}
}
