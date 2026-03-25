# Author: Murtaza N

# THE CONNECTION (Provider GCP)
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
    "artifactregistry.googleapis.com"
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
      #   size  = 12
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


# THE VAULT (Secret Manager)
resource "google_secret_manager_secret" "db_pwd" {
  secret_id  = "test-db-password"
  depends_on = [google_project_service.gcp_services]
  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "db_pwd_val" {
  secret      = google_secret_manager_secret.db_pwd.id
  secret_data = "test_password_123" # The actual password
}

# 4. THE DATABASE (Cloud SQL)
resource "google_sql_database_instance" "postgres" {
  name                = "mlops-test-db"
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
  password = google_secret_manager_secret_version.db_pwd_val.secret_data
}

# 5. THE WAREHOUSE (Artifact Registry)
resource "google_artifact_registry_repository" "repo" {
  location      = "us-west1"
  repository_id = "mlops-test-docker-repo"
  format        = "DOCKER"
  depends_on    = [google_project_service.gcp_services]
}
