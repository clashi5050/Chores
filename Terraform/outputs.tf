# =============================================================================
# outputs.tf
# -----------------------------------------------------------------------------
# Surfaces values needed after provisioning. The deployment API token is
# sensitive and is used to configure the AZURE_STATIC_WEB_APPS_API_TOKEN secret
# for the separate content-deploy workflow.
# =============================================================================

output "static_web_app_name" {
  description = "Name of the provisioned Static Web App."
  value       = azurerm_static_web_app.app.name
}

output "resource_group_name" {
  description = "Resource group containing the Static Web App."
  value       = azurerm_resource_group.swa.name
}

output "default_host_name" {
  description = "Auto-generated public hostname (https://<this>)."
  value       = azurerm_static_web_app.app.default_host_name
}

output "api_key" {
  description = "Deployment API token for the content-deploy workflow. Store as the AZURE_STATIC_WEB_APPS_API_TOKEN secret."
  value       = azurerm_static_web_app.app.api_key
  sensitive   = true
}

output "household_pin" {
  description = "Shared PIN the Chore Wars app needs to call its API. Enter it once per device; it's cached in that browser's localStorage."
  value       = random_password.household_pin.result
  sensitive   = true
}