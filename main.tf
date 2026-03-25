provider "google" {
  project = "github-actions-485720" # Replace with your project ID
  region  = "us-west1"
  zone    = "us-west1-b"
}

# Enable Compute Engine API - added to fix API error
resource "google_project_service" "compute" {
  project = "github-actions-485720"
  service = "compute.googleapis.com"

  # This ensures the API is enabled before the VM tries to create
  disable_on_destroy = false
}

resource "google_compute_instance" "mlops-test-vm" {
  # Ensure this runs only after the API is enabled - added to fix API error
  # ensures the order of operations
  depends_on = [google_project_service.compute]

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
# Enable the SQL Admin API (essential for Cloud SQL)
resource "google_project_service" "sqladmin" {
  service            = "sqladmin.googleapis.com"
  disable_on_destroy = false
}

# Create the Cloud SQL Instance
resource "google_sql_database_instance" "postgres_instance" {
  name             = "mlops-db-instance"
  database_version = "POSTGRES_15"
  region           = "us-west1" # Using a stable region to avoid stockouts

  depends_on = [google_project_service.sqladmin]

  settings {
    # 'db-f1-micro' is the cheapest for DB instance
    tier = "db-f1-micro"

    ip_configuration {
      ipv4_enabled = true
      # Note: For SavVio, probably use private IP
    }
  }

  # This prevents accidental deletion of the instance
  deletion_protection = false
}

# Create the actual Database inside the Instance
resource "google_sql_database" "mydatabase" {
  name     = "mlops_test_db"
  instance = google_sql_database_instance.postgres_instance.name
}

# Create a Database User
resource "google_sql_user" "users" {
  name     = "dbadmin"
  instance = google_sql_database_instance.postgres_instance.name
  password = "your-secure-password" # Best practice: use a variable for this
}
