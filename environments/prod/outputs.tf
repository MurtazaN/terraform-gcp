output "cloud_run_url" {
  description = "The URL of the deployed Cloud Run service"
  value       = module.core.cloud_run_url
}

output "db_connection_name" {
  description = "The connection name of the Cloud SQL instance"
  value       = module.core.db_connection_name
}

output "artifact_registry_repo" {
  description = "The Artifact Registry repository name"
  value       = module.core.artifact_registry_repo
}

output "database_password_secret_name" {
  description = "The Secret Manager Secret name for the database password"
  value       = module.core.database_password_secret_name
}
