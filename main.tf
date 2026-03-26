# Author: Murtaza N

locals {
  prefix = "${var.app_name}-${var.environment}"

  common_labels = {
    environment = var.environment
    owner       = "team-terraform"
  }
}

# Enable APIs
resource "google_project_service" "gcp_services" {
  for_each = toset([
    "compute.googleapis.com",
    "sqladmin.googleapis.com",
    "secretmanager.googleapis.com",
    "artifactregistry.googleapis.com",
    "run.googleapis.com"
  ])
  service            = each.key
  disable_on_destroy = false
}

resource "google_compute_instance" "mlops-test-vm" {
  # ensures the order of operations
  depends_on = [google_project_service.gcp_services]

  name         = "${local.prefix}-vm"
  machine_type = "e2-micro"
  zone         = var.zone

  labels = local.common_labels

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"
    }
  }

  network_interface {
    network = "default"
  }
}

resource "google_storage_bucket" "mlops-test-bucket" {
  name                        = "${local.prefix}-bucket-unique"
  location                    = var.region
  uniform_bucket_level_access = true
  force_destroy               = true
}

# -----------------------------------------------------------------------------

# GENERATE A SECURE RANDOM PASSWORD
resource "random_password" "db_pwd" {
  length           = 24
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?" # Avoid chars that can cause issues with connection strings
}

# 3. THE VAULT (Secret Manager)
resource "google_secret_manager_secret" "db_pwd" {
  secret_id  = "${var.environment}-db-password"
  depends_on = [google_project_service.gcp_services]
  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "db_pwd_val" {
  secret      = google_secret_manager_secret.db_pwd.id
  secret_data = random_password.db_pwd.result
}

# 4. THE DATABASE (Cloud SQL)
resource "google_sql_database_instance" "postgres" {
  name                = "${local.prefix}-db-instance"
  database_version    = "POSTGRES_15"
  region              = var.region
  deletion_protection = false
  depends_on          = [google_project_service.gcp_services]

  settings {
    tier = var.db_tier # Cheapest version for labs
  }
}

resource "google_sql_user" "admin" {
  name     = "${var.environment}-db-admin"
  instance = google_sql_database_instance.postgres.name
  password = random_password.db_pwd.result # References the same generated password
}

resource "google_sql_database" "mlops_db" {
  name     = "${local.prefix}-db"
  instance = google_sql_database_instance.postgres.name
}

# 5. THE RUNNER (Cloud Run)
resource "google_cloud_run_v2_service" "mlops_app" {
  name                = "${var.app_name}-app"
  location            = var.region
  deletion_protection = false

  depends_on = [
    google_project_service.gcp_services,
    google_secret_manager_secret_iam_member.cloudrun_secret_access
  ]

  template {
    # Connect to Cloud SQL
    volumes {
      name = "cloudsql"
      cloud_sql_instance {
        instances = [google_sql_database_instance.postgres.connection_name]
      }
    }

    containers {
      image = var.container_image

      ports {
        container_port = 8080
      }

      # Pass DB connection info as env vars
      env {
        name  = "DB_USER"
        value = google_sql_user.admin.name
      }
      env {
        name = "DB_PASS"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.db_pwd.secret_id
            version = "latest"
          }
        }
      }
      env {
        name  = "DB_NAME"
        value = google_sql_database.mlops_db.name
      }
      env {
        name  = "INSTANCE_CONNECTION_NAME"
        value = google_sql_database_instance.postgres.connection_name
      }

      # Mount the Cloud SQL proxy socket
      volume_mounts {
        name       = "cloudsql"
        mount_path = "/cloudsql"
      }
    }
  }
}

# Make Cloud Run publicly accessible (unauthenticated)
resource "google_cloud_run_v2_service_iam_member" "public_access" {
  name     = google_cloud_run_v2_service.mlops_app.name
  location = google_cloud_run_v2_service.mlops_app.location
  role     = "roles/run.invoker"
  member   = "allUsers"
}

# Grant Cloud Run access to read the secret
resource "google_secret_manager_secret_iam_member" "cloudrun_secret_access" {
  secret_id = google_secret_manager_secret.db_pwd.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${data.google_project.project.number}-compute@developer.gserviceaccount.com"
}

# 6. THE WAREHOUSE (Artifact Registry)
resource "google_artifact_registry_repository" "repo" {
  location      = var.region
  repository_id = "${local.prefix}-docker-repo"
  format        = "DOCKER"
  depends_on    = [google_project_service.gcp_services]
}
