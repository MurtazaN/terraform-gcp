module "core" {
  source = "../../modules/mlops-core"

  project_id      = "github-actions-485720"
  region          = "us-west1"
  zone            = "us-west1-b"
  app_name        = "mlops"
  environment     = "test"
  db_tier         = "db-f1-micro"
  container_image = "us-west1-docker.pkg.dev/github-actions-485720/mlops-test-docker-repo/test-app2:v1"
}
