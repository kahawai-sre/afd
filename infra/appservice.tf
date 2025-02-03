

resource "azurerm_service_plan" "app_service_plan" {
  name                = local.app_service_plan_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  sku_name     = var.app_service_plan_sku_name
  os_type      = "Windows"
  worker_count = var.app_service_plan_capacity
}

resource "azurerm_windows_web_app" "app_public" {
  name                    = local.app_name_public
  location                = azurerm_resource_group.rg.location
  resource_group_name     = azurerm_resource_group.rg.name
  service_plan_id         = azurerm_service_plan.app_service_plan.id
  https_only              = true
  client_affinity_enabled = true
  site_config {
    ftps_state                    = "Disabled"
    minimum_tls_version           = "1.2"
    websockets_enabled            = true
    always_on                     = true
    use_32_bit_worker             = false
    ip_restriction_default_action = "Deny"
    application_stack {
      current_stack  = "dotnetcore"
      dotnet_version = "v8.0"
    }
    ip_restriction {

      service_tag               = "AzureFrontDoor.Backend"
      ip_address                = null
      virtual_network_subnet_id = null
      action                    = "Allow"
      priority                  = 100
      headers {
        x_azure_fdid      = [azurerm_cdn_frontdoor_profile.my_front_door.resource_guid]
        x_fd_health_probe = []
        x_forwarded_for   = []
        x_forwarded_host  = []
      }
      name = "Allow traffic from Front Door"
    }
  }
  app_settings = {
    ApplicationInsightsAgent_EXTENSION_VERSION = "~3"
    APPINSIGHTS_INSTRUMENTATIONKEY             = azurerm_application_insights.ai.instrumentation_key
    APPLICATIONINSIGHTS_CONNECTION_STRING      = azurerm_application_insights.ai.connection_string
    ASPNETCORE_ENVIRONMENT                     = "Development"
    AFD_FQDN                                   = azurerm_cdn_frontdoor_endpoint.my_endpoint.host_name
  }
  lifecycle {
    ignore_changes = [site_config[0].application_stack[0].dotnet_version]
  }
}


