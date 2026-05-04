project_name            = "customer-support"
environment             = "prod"
region                  = "europe-west1"
vertex_model_id         = "gemini-2.5-flash"
mcp_server_url          = "https://order-mcp-74afyau24q-uc.a.run.app/mcp"
max_instance_count      = 10
request_timeout_seconds = 60
# project_id and image come from -var flags in scripts/deploy-gcp.sh
