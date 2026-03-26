output "cloud_run_url" {
  description = "The URL of the deployed Cloud Run service"
  value       = google_cloud_run_v2_service.mlops_app.uri
}

output "db_connection_name" {
  description = "The connection name of the Cloud SQL instance"
  value       = google_sql_database_instance.postgres.connection_name
}

output "artifact_registry_repo" {
  description = "The Artifact Registry repository name"
  value       = google_artifact_registry_repository.repo.name
}

output "database_password_secret_name" {
  description = "The Secret Manager Secret name for the database password"
  value       = google_secret_manager_secret.db_pwd.secret_id
}
