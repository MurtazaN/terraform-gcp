variable "project_id" {
  type        = string
  description = "The GCP project ID"
  default     = "github-actions-485720"
}

variable "region" {
  type        = string
  description = "The default GCP region"
  default     = "us-west1"
}

variable "zone" {
  type        = string
  description = "The default GCP zone"
  default     = "us-west1-b"
}

variable "app_name" {
  type        = string
  description = "Application name"
  default     = "mlops"
}

variable "environment" {
  type        = string
  description = "Environment name (e.g. test, dev, prod)"
  default     = "test"
}

variable "db_tier" {
  type        = string
  description = "The database tier (e.g., db-f1-micro)"
  default     = "db-f1-micro"
}

variable "container_image" {
  type        = string
  description = "The container image to deploy to Cloud Run"
  default     = "us-west1-docker.pkg.dev/github-actions-485720/mlops-test-docker-repo/test-app2:v1"
}
