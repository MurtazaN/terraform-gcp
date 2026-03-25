# Author: Murtaza N

# THE CONNECTION (Provider GCP)
terraform {
  required_providers {
    google = {
      source = "hashicorp/google"
    }
    random = {
      source = "hashicorp/random"
    }
  }
}

provider "google" {
  project = "github-actions-485720"
  region  = "us-west1" # Using Oregon - it has high capacity
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
  service            = each.key # ??
  disable_on_destroy = false
}

resource "google_compute_instance" "mlops-test-vm" {
  # Ensure this runs only after the API is enabled - added to fix API error
  # ensures the order of operations
  depends_on = [google_project_service.gcp_services]

  name         = "mlops-test-vm"
  machine_type = "e2-micro"
  zone         = "us-west1-b"

  labels = {
    environment = "development"
    owner       = "team-terraform"
  }

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
  name                        = "mlops-test-bucket-unique"
  location                    = "us-west1"
  uniform_bucket_level_access = true # added to fix bucket creation
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
  secret_id  = "test-db-password"
  depends_on = [google_project_service.gcp_services]
  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "db_pwd_val" {
  secret      = google_secret_manager_secret.db_pwd.id
  secret_data = random_password.db_pwd.result # Auto-generated, never hardcoded
}

# 4. THE DATABASE (Cloud SQL)
resource "google_sql_database_instance" "postgres" {
  name                = "mlops-test-db-instance"
  database_version    = "POSTGRES_15"
  region              = "us-west1"
  deletion_protection = false
  depends_on          = [google_project_service.gcp_services]

  settings {
    tier = "db-f1-micro" # Cheapest version for labs
  }
}

resource "google_sql_user" "admin" {
  name     = "test-db-admin"
  instance = google_sql_database_instance.postgres.name
  password = random_password.db_pwd.result # References the same generated password
}

resource "google_sql_database" "mlops_db" {
  name     = "mlops-test-db"
  instance = google_sql_database_instance.postgres.name
}

# 5. THE RUNNER (Cloud Run)
resource "google_cloud_run_v2_service" "mlops_app" {
  name     = "mlops-app"
  location = "us-west1"

  depends_on = [google_project_service.gcp_services]

  template {
    # Connect to Cloud SQL
    volumes {
      name = "cloudsql"
      cloud_sql_instance {
        instances = [google_sql_database_instance.postgres.connection_name]
      }
    }

    containers {
      # TODO: Replace with your Artifact Registry image once built
      # Format: us-west1-docker.pkg.dev/github-actions-485720/mlops-test-docker-repo/YOUR_IMAGE:TAG
      image = "us-west1-docker.pkg.dev/github-actions-485720/mlops-test-docker-repo/test-app:v1"

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
# To make it private, remove this resource entirely
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
  member    = "serviceAccount:${google_cloud_run_v2_service.mlops_app.template[0].service_account}" # Uses default compute SA
}

# 6. THE WAREHOUSE (Artifact Registry)
resource "google_artifact_registry_repository" "repo" {
  location      = "us-west1"
  repository_id = "mlops-test-docker-repo"
  format        = "DOCKER"
  depends_on    = [google_project_service.gcp_services]
}
