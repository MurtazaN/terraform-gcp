provider "google" {
  project = "github-actions-485720" # Replace with your project ID
  region  = "us-east1"
  zone    = "us-east1-a"
}

# resource "google_compute_instance" "mlops-test-vm" {
#   name         = "mlops-test-vm"
#   machine_type = "f1-micro"
#   zone         = "us-east1-a"

#   labels = {
#     environment = "development"
#     owner       = "team-terraform"
#   }

#   boot_disk {
#     initialize_params {
#       image = "debian-cloud/debian-11"
#       size  = 12
#     }
#   }

#   network_interface {
#     network = "default"
#   }
# }

resource "google_storage_bucket" "mlops-test-bucket" {
  name          = "mlops-test-bucket-unique"
  location      = "us-east1"
  force_destroy = true
}
