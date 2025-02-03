resource "azurerm_log_analytics_workspace" "la" {
  name                = local.la_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  retention_in_days   = 30
}
resource "azurerm_application_insights" "ai" {
  name                = local.la_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  workspace_id        = azurerm_log_analytics_workspace.la.id
  application_type    = "web"
}

output "instrumentation_key" {
  value     = azurerm_application_insights.ai.instrumentation_key
  sensitive = true
}

output "app_id" {
  value = azurerm_application_insights.ai.app_id
}

output "connection_string" {
  value     = azurerm_application_insights.ai.connection_string
  sensitive = true
}
