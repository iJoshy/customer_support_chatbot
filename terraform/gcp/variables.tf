variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "project_name" {
  description = "Resource name prefix"
  type        = string
  default     = "customer-support"
  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.project_name))
    error_message = "project_name must contain only lowercase letters, numbers, and hyphens."
  }
}

variable "environment" {
  description = "Environment name (dev, test, prod)"
  type        = string
  validation {
    condition     = contains(["dev", "test", "prod"], var.environment)
    error_message = "environment must be one of: dev, test, prod."
  }
}

variable "region" {
  description = "GCP region for Cloud Run, Artifact Registry, Vertex AI, and the memory bucket"
  type        = string
  default     = "us-central1"
}

variable "image" {
  description = "Fully-qualified container image to deploy (e.g. us-central1-docker.pkg.dev/<project>/customer-support-dev/api:<sha>)"
  type        = string
}

variable "vertex_model_id" {
  description = "Vertex AI Gemini model ID"
  type        = string
  default     = "gemini-2.5-flash"
}

variable "mcp_server_url" {
  description = "Meridian order MCP Streamable HTTP endpoint"
  type        = string
  default     = "https://order-mcp-74afyau24q-uc.a.run.app/mcp"
}

variable "cors_origins" {
  description = "Comma-separated CORS origins (defaults to allow-all for dev; restrict in prod)"
  type        = string
  default     = "*"
}

variable "max_instance_count" {
  description = "Cloud Run autoscaler upper bound (parity with the API Gateway throttle on AWS)"
  type        = number
  default     = 5
}

variable "request_timeout_seconds" {
  description = "Per-request timeout in seconds (parity with lambda_timeout on AWS)"
  type        = number
  default     = 60
}
