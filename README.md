# MLOps Infrastructure — Terraform on GCP

Author: Murtaza N

## Overview

This project provisions a complete MLOps development environment on Google Cloud Platform using Terraform. It sets up compute, storage, a PostgreSQL database, a Docker registry, and a Cloud Run service — all wired together securely.

## Architecture

| Resource | GCP Service | Name |
|---|---|---|
| Compute VM | Compute Engine | `mlops-test-vm` |
| Object Storage | Cloud Storage | `mlops-test-bucket-unique` |
| Database Instance | Cloud SQL (PostgreSQL 15) | `mlops-test-db-instance` |
| Database | Cloud SQL Database | `mlops-test-db` |
| Secrets | Secret Manager | `test-db-password` |
| Container Registry | Artifact Registry | `mlops-test-docker-repo` |
| App Service | Cloud Run | `mlops-app` |

All resources are deployed in **us-west1 (Oregon)**.

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/downloads) >= 1.0
- [Google Cloud SDK](https://cloud.google.com/sdk/docs/install) (`gcloud`)
- A GCP project with billing enabled
- Docker installed locally (for building and pushing images)
- Authenticated via `gcloud auth application-default login`

## Project Structure

```
.
├── main.tf          # All infrastructure resources
└── README.md
```

## Getting Started

### 1. Initialize Terraform

```bash
terraform init
```

### 2. Build and Push the Docker Image

Before deploying Cloud Run, you need an image in Artifact Registry.

```bash
# Authenticate Docker with GCP
gcloud auth configure-docker us-west1-docker.pkg.dev

# Build the image for both amd64 and arm64 platforms since cloud run supports only amd64
docker buildx build --platform linux/amd64,linux/arm64 --push -t us-west1-docker.pkg.dev/github-actions-485720/mlops-test-docker-repo/test-app:v1 .

# Push to Artifact Registry
docker push us-west1-docker.pkg.dev/github-actions-485720/mlops-test-docker-repo/test-app:v1
```

### 3. Preview Changes

```bash
terraform plan
```

### 4. Deploy

```bash
terraform apply
```

### 5. Access the Webpage

Once deployed, Cloud Run will generate a URL for your service. You can retrieve it using:

```bash
gcloud run services describe mlops-app --region=us-west1 --format="value(status.url)"
```

Open this URL in your web browser. As defined in `app.py` and containerized via the `Dockerfile`, a simple Flask application listens on port 8080 and exposes a single route at `/`. When you visit the site, you should see the message: **"Cloud Run is working!"**

### 6. Tear Down

```bash
terraform destroy
```

## Security

- The database password is **auto-generated** using Terraform's `random_password` resource (24 characters).
- The password is stored in **Secret Manager** and never hardcoded in code.
- Cloud Run reads the password from Secret Manager at runtime via `secret_key_ref`.
- Only the Cloud Run service account is granted access to the secret.

> **Note:** Terraform stores sensitive values in its state file. For production use, configure a remote backend with encryption (e.g., a GCS bucket) instead of local state.

## Cloud Run

The Cloud Run service (`mlops-app`) is deployed as **publicly accessible** (unauthenticated). To make it private, remove the `google_cloud_run_v2_service_iam_member.public_access` resource from `main.tf`.

### Environment Variables Available to the Container

| Variable | Description |
|---|---|
| `DB_USER` | Cloud SQL admin username |
| `DB_PASS` | Database password (from Secret Manager) |
| `DB_NAME` | Database name (`mlops-test-db`) |
| `INSTANCE_CONNECTION_NAME` | Cloud SQL connection string for the proxy |

The Cloud SQL proxy socket is mounted at `/cloudsql`.

## Useful Commands

```bash
# Retrieve the database password
gcloud secrets versions access latest --secret="test-db-password"

# Get the Cloud Run service URL
gcloud run services describe mlops-app --region=us-west1 --format="value(status.url)"

# View Cloud Run logs
gcloud run services logs read mlops-app --region=us-west1

# List images in Artifact Registry
gcloud artifacts docker images list us-west1-docker.pkg.dev/github-actions-485720/mlops-test-docker-repo
```

## GCP APIs Enabled

This project automatically enables the following APIs:

- Compute Engine (`compute.googleapis.com`)
- Cloud SQL Admin (`sqladmin.googleapis.com`)
- Secret Manager (`secretmanager.googleapis.com`)
- Artifact Registry (`artifactregistry.googleapis.com`)
- Cloud Run (`run.googleapis.com`)