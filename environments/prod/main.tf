module "core" {
  source = "../../modules/mlops-core"

  project_id      = "github-actions-485720"
  region          = "us-west1"
  zone            = "us-west1-b"
  app_name        = "mlops"
  environment     = "prod"
  db_tier         = "db-custom-2-7680"
  container_image = "us-west1-docker.pkg.dev/github-actions-485720/mlops-test-docker-repo/test-app2:v1"
}
