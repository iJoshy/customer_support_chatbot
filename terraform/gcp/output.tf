output "cloud_run_url" {
  description = "Public HTTPS URL of the Cloud Run service"
  value       = google_cloud_run_v2_service.api.uri
}

output "cloud_run_service_name" {
  description = "Cloud Run service name"
  value       = google_cloud_run_v2_service.api.name
}

output "gcs_memory_bucket" {
  description = "Cloud Storage bucket holding chat session memory"
  value       = google_storage_bucket.memory.name
}

output "artifact_registry_repository" {
  description = "Artifact Registry repo path for the chatbot image"
  value       = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.api.repository_id}"
}

output "service_account_email" {
  description = "Service account used by Cloud Run"
  value       = google_service_account.api.email
}
