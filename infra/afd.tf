

resource "azurerm_cdn_frontdoor_profile" "my_front_door" {
  name                = local.front_door_profile_name
  resource_group_name = azurerm_resource_group.rg.name
  sku_name            = var.front_door_sku_name
}

resource "azurerm_cdn_frontdoor_endpoint" "my_endpoint" {
  name                     = local.front_door_endpoint_name
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.my_front_door.id
}

resource "azurerm_cdn_frontdoor_origin_group" "my_origin_group" {
  name                     = local.front_door_origin_group_name
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.my_front_door.id
  session_affinity_enabled = true

  load_balancing {
    sample_size                 = 4
    successful_samples_required = 3
  }

  health_probe {
    path                = "/"
    request_type        = "HEAD"
    protocol            = "Https"
    interval_in_seconds = 100
  }
}

resource "azurerm_cdn_frontdoor_origin" "my_app_service_origin" {
  name                          = local.front_door_origin_name
  cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.my_origin_group.id

  enabled                        = true
  host_name                      = azurerm_windows_web_app.app_public.default_hostname
  http_port                      = 80
  https_port                     = 443
  origin_host_header             = azurerm_windows_web_app.app_public.default_hostname
  priority                       = 1
  weight                         = 1000
  certificate_name_check_enabled = true
}

resource "azurerm_cdn_frontdoor_route" "my_route" {
  name                          = local.front_door_route_name
  cdn_frontdoor_endpoint_id     = azurerm_cdn_frontdoor_endpoint.my_endpoint.id
  cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.my_origin_group.id
  cdn_frontdoor_origin_ids      = [azurerm_cdn_frontdoor_origin.my_app_service_origin.id]

  supported_protocols    = ["Http", "Https"]
  patterns_to_match      = ["/*"]
  forwarding_protocol    = "HttpsOnly"
  link_to_default_domain = true
  https_redirect_enabled = true
}

resource "azurerm_cdn_frontdoor_firewall_policy" "my_waf" {
  name                              = local.waf_name
  resource_group_name               = azurerm_resource_group.rg.name
  sku_name                          = azurerm_cdn_frontdoor_profile.my_front_door.sku_name
  enabled                           = true
  mode                              = "Prevention" # "Detection"
  custom_block_response_status_code = 403
  custom_block_response_body        = "eWVhaHJpZ2h0bWF0ZQ=="

  # managed_rule {
  #   type    = "Microsoft_DefaultRuleSet"
  #   version = "2.1"
  #   action  = "Log" #"Log"
  # }
  # managed_rule {
  #   type    = "Microsoft_BotManagerRuleSet"
  #   version = "1.1"
  #   action  = "Log"
  # }

  custom_rule {
    name     = "GeoBlock"
    enabled  = true
    priority = 1
    type     = "MatchRule" #"RateLimitRule"
    action   = "Block"     #Allow, BLock, Log, Redirect
    match_condition {
      match_variable     = "RemoteAddr"
      operator           = "GeoMatch"
      negation_condition = true
      match_values       = ["AU", "NZ"]
    }
  }

  custom_rule {
    name                           = "RateLimit"
    enabled                        = true
    priority                       = 2
    type                           = "RateLimitRule"
    action                         = "Block" #Allow, BLock, Log, Redirect
    rate_limit_duration_in_minutes = 5
    rate_limit_threshold           = 1000
    match_condition {
      match_variable     = "RemoteAddr"
      operator           = "IPMatch"
      negation_condition = true
      match_values       = ["150.107.174.198"]
    }
  }
}

resource "azurerm_cdn_frontdoor_security_policy" "my_afd_waf_policy" {
  name                     = local.waf_name
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.my_front_door.id

  security_policies {
    firewall {
      cdn_frontdoor_firewall_policy_id = azurerm_cdn_frontdoor_firewall_policy.my_waf.id

      association {
        domain {
          cdn_frontdoor_domain_id = azurerm_cdn_frontdoor_endpoint.my_endpoint.id
        }
        patterns_to_match = ["/*"]
      }
    }
  }
}
