locals {
  name_prefix = "${var.project_name}"

  common_labels = {
    project     = var.project_name
    environment = var.environment
    managed_by  = "terraform"
  }
}

# Enable the GCP APIs we depend on. disable_on_destroy=false keeps APIs on
# even if a project is destroyed, which is the safer default for shared projects.
resource "google_project_service" "required" {
  for_each = toset([
    "run.googleapis.com",
    "artifactregistry.googleapis.com",
    "aiplatform.googleapis.com",
    "storage.googleapis.com",
    "iam.googleapis.com",
    "cloudbuild.googleapis.com",
  ])

  service            = each.key
  disable_on_destroy = false
}

# ---------------------------------------------------------------------------
# Container registry for the Cloud Run image
# ---------------------------------------------------------------------------

resource "google_artifact_registry_repository" "api" {
  location      = var.region
  repository_id = local.name_prefix
  description   = "Container images for ${local.name_prefix}"
  format        = "DOCKER"
  labels        = local.common_labels

  depends_on = [google_project_service.required]
}

# ---------------------------------------------------------------------------
# Session memory bucket (replaces the AWS S3 memory bucket)
# ---------------------------------------------------------------------------

resource "google_storage_bucket" "memory" {
  name                        = "${local.name_prefix}-${var.project_id}"
  location                    = var.region
  force_destroy               = false
  uniform_bucket_level_access = true
  labels                      = local.common_labels

  versioning {
    enabled = false
  }

  depends_on = [google_project_service.required]
}

# ---------------------------------------------------------------------------
# Service account for the Cloud Run service
# ---------------------------------------------------------------------------

resource "google_service_account" "api" {
  account_id   = "${local.name_prefix}-api"
  display_name = "Cloud Run service account for ${local.name_prefix}"
  description  = "Identity used by the chatbot Cloud Run service to call Vertex AI and GCS"

  depends_on = [google_project_service.required]
}

# Vertex AI Gemini access
resource "google_project_iam_member" "api_vertex" {
  project = var.project_id
  role    = "roles/aiplatform.user"
  member  = "serviceAccount:${google_service_account.api.email}"
}

# Read/write session JSON in the memory bucket
resource "google_storage_bucket_iam_member" "api_memory" {
  bucket = google_storage_bucket.memory.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.api.email}"
}

# ---------------------------------------------------------------------------
# Cloud Run service (replaces Lambda + API Gateway)
# ---------------------------------------------------------------------------

resource "google_cloud_run_v2_service" "api" {
  name                = "${local.name_prefix}-api"
  location            = var.region
  deletion_protection = false
  ingress             = "INGRESS_TRAFFIC_ALL"
  labels              = local.common_labels

  template {
    service_account = google_service_account.api.email
    timeout         = "${var.request_timeout_seconds}s"

    scaling {
      min_instance_count = 0
      max_instance_count = var.max_instance_count
    }

    containers {
      image = var.image

      ports {
        container_port = 8080
      }

      resources {
        limits = {
          cpu    = "1"
          memory = "512Mi"
        }
        cpu_idle          = true
        startup_cpu_boost = true
      }

      env {
        name  = "LLM_PROVIDER"
        value = "vertex"
      }
      env {
        name  = "SESSION_STORE"
        value = "gcs"
      }
      env {
        name  = "GCP_PROJECT_ID"
        value = var.project_id
      }
      env {
        name  = "GCP_REGION"
        value = var.region
      }
      env {
        name  = "VERTEX_MODEL_ID"
        value = var.vertex_model_id
      }
      env {
        name  = "GCS_BUCKET"
        value = google_storage_bucket.memory.name
      }
      env {
        name  = "MCP_SERVER_URL"
        value = var.mcp_server_url
      }
      env {
        name  = "CORS_ORIGINS"
        value = var.cors_origins
      }
    }
  }

  depends_on = [
    google_project_service.required,
    google_project_iam_member.api_vertex,
    google_storage_bucket_iam_member.api_memory,
  ]
}

# Allow public unauthenticated traffic to the chat endpoint, mirroring the
# current API Gateway behavior on AWS.
resource "google_cloud_run_v2_service_iam_member" "api_invoker" {
  project  = var.project_id
  location = google_cloud_run_v2_service.api.location
  name     = google_cloud_run_v2_service.api.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}
