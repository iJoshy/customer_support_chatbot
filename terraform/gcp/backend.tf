terraform {
  backend "gcs" {
    # bucket and prefix supplied via -backend-config from scripts/deploy-gcp.sh
    # Example:
    #   bucket = "<project_id>-terraform-state"
    #   prefix = "<environment>/customer-support-chatbot"
  }
}
