##########
### Local setup
##########
resource "random_id" "gen" {
  byte_length = 8
  prefix = "pbc-"
}

locals {
  subaccount_domain = substr(lower(random_id.gen.b64_url), 0, 32)
  subaccount_cf_org = local.subaccount_domain
}


##########
### Subaccount
##########
resource "btp_subaccount" "pbc_workshop" {
  name      = var.subaccount_name
  subdomain = local.subaccount_domain
  region    = lower(var.region)
}


##########
### Entitlements
##########
resource "btp_subaccount_entitlement" "bas" {
  subaccount_id = btp_subaccount.pbc_workshop.id
  service_name  = "sapappstudio"
  plan_name     = "standard-edition"
}

resource "btp_subaccount_entitlement" "build_workzone_standard" {
  subaccount_id = btp_subaccount.pbc_workshop.id
  service_name  = "build-workzone-standard"
  plan_name     = "standard"
}

resource "btp_subaccount_entitlement" "ai_launchpad" {
  subaccount_id = btp_subaccount.pbc_workshop.id
  service_name  = "ai-launchpad"
  plan_name     = "standard"
}

resource "btp_subaccount_entitlement" "ai_core" {
  subaccount_id = btp_subaccount.pbc_workshop.id
  service_name  = "aicore"
  plan_name     = "extended"
}

resource "btp_subaccount_entitlement" "integration_suite" {
  subaccount_id = btp_subaccount.pbc_workshop.id
  service_name  = "integrationsuite"
  plan_name     = "standard_edition"
}

resource "btp_subaccount_entitlement" "event_mesh_message_client" {
  subaccount_id = btp_subaccount.pbc_workshop.id
  service_name  = "hana-event-mesh-message-client"
  plan_name     = "message-client"
}

resource "btp_subaccount_entitlement" "destination" {
  subaccount_id = btp_subaccount.pbc_workshop.id
  service_name  = "destination"
  plan_name     = "lite"
}

resource "btp_subaccount_entitlement" "hana_cloud_tools" {
  subaccount_id = btp_subaccount.pbc_workshop.id
  service_name  = "hana-cloud-tools"
  plan_name     = "tools"
}

resource "btp_subaccount_entitlement" "hana_cloud" {
  subaccount_id = btp_subaccount.pbc_workshop.id
  service_name  = "hana-cloud"
  plan_name     = "hana"
}


##########
### Environment
##########
# Creation of Cloud Foundry environment
resource "btp_subaccount_environment_instance" "cloudfoundry" {
  subaccount_id    = btp_subaccount.pbc_workshop.id
  name             = local.subaccount_cf_org
  environment_type = "cloudfoundry"
  service_name     = "cloudfoundry"
  plan_name        = "standard"
  parameters = jsonencode({
    instance_name = local.subaccount_cf_org
  })
}


##########
### Services Subscriptions
##########
resource "btp_subaccount_subscription" "integration_suite" {
  subaccount_id = btp_subaccount.pbc_workshop.id
  app_name      = "integrationsuite"
  plan_name     = btp_subaccount_entitlement.integration_suite.plan_name
  depends_on    = [btp_subaccount_entitlement.integration_suite]
}

resource "btp_subaccount_subscription" "ai_launchpad" {
  subaccount_id = btp_subaccount.pbc_workshop.id
  app_name      = "ai-launchpad"
  plan_name     = btp_subaccount_entitlement.ai_launchpad.plan_name
  depends_on    = [btp_subaccount_entitlement.ai_launchpad]
}

resource "btp_subaccount_subscription" "build_workzone_standard" {
  subaccount_id = btp_subaccount.pbc_workshop.id
  app_name      = "build-workzone-standard"
  plan_name     = btp_subaccount_entitlement.build_workzone_standard.plan_name
  depends_on    = [btp_subaccount_entitlement.build_workzone_standard]
}

# Create app subscription to SAP Build Apps (depends on entitlement)
resource "btp_subaccount_subscription" "bas" {
  subaccount_id = btp_subaccount.pbc_workshop.id
  app_name      = "sapappstudio"
  plan_name     = btp_subaccount_entitlement.bas.plan_name
  depends_on    = [btp_subaccount_entitlement.bas]
}

 # Create app subscription to SAP HANA Cloud Tools
resource "btp_subaccount_subscription" "hana_cloud_tools" {
  subaccount_id = btp_subaccount.pbc_workshop.id
  app_name      = "hana-cloud-tools"
  plan_name     = "tools"
  depends_on    = [btp_subaccount_entitlement.hana_cloud_tools]
}

##########
### Services Instances
##########

### Setup AI Core ###
# Get plan for SAP AI Core service
data "btp_subaccount_service_plan" "ai_core" {
  subaccount_id = btp_subaccount.pbc_workshop.id
  offering_name = "aicore"
  name          = "extended"
  depends_on    = [btp_subaccount_entitlement.ai_core]
}

# Create service instance for SAP AI Core service
resource "btp_subaccount_service_instance" "ai_core" {
  subaccount_id  = btp_subaccount.pbc_workshop.id
  serviceplan_id = data.btp_subaccount_service_plan.ai_core.id
  name           = "my-ai-core-instance"
  depends_on     = [btp_subaccount_entitlement.ai_core]
}

# Create service binding to SAP AI Core service (exposed for a specific user group)
resource "btp_subaccount_service_binding" "ai_core_binding" {
  subaccount_id       = btp_subaccount.pbc_workshop.id
  service_instance_id = btp_subaccount_service_instance.ai_core.id
  name                = "ai-core-key"
}

### Setup Destination ###
# Get plan for destination service
data "btp_subaccount_service_plan" "destination" {
  subaccount_id = btp_subaccount.pbc_workshop.id
  offering_name = "destination"
  name          = "lite"
  depends_on    = [btp_subaccount_entitlement.destination]
}

# Create service instance
resource "btp_subaccount_service_instance" "destination" {
  subaccount_id  = btp_subaccount.pbc_workshop.id
  serviceplan_id = data.btp_subaccount_service_plan.destination.id
  name           = "destination"
  depends_on     = [btp_subaccount_service_binding.ai_core_binding, data.btp_subaccount_service_plan.destination]
  parameters = jsonencode({
    HTML5Runtime_enabled = true
    init_data = {
      subaccount = {
        existing_destinations_policy = "update"
        destinations = [
          # This is the destination to the ai-core binding
          {
            Description                = "[Do not delete] PROVIDER_AI_CORE_DESTINATION_HUB"
            Type                       = "HTTP"
            clientId                   = "${jsondecode(btp_subaccount_service_binding.ai_core_binding.credentials)["clientid"]}"
            clientSecret               = "${jsondecode(btp_subaccount_service_binding.ai_core_binding.credentials)["clientsecret"]}"
            "HTML5.DynamicDestination" = true
            "HTML5.Timeout"            = 5000
            Authentication             = "OAuth2ClientCredentials"
            Name                       = "PROVIDER_AI_CORE_DESTINATION_HUB"
            tokenServiceURL            = "${jsondecode(btp_subaccount_service_binding.ai_core_binding.credentials)["url"]}/oauth/token"
            ProxyType                  = "Internet"
            URL                        = "${jsondecode(btp_subaccount_service_binding.ai_core_binding.credentials)["serviceurls"]["AI_API_URL"]}/v2"
            tokenServiceURLType        = "Dedicated"
          }
        ]
      }
    }
  })
}

### Setup HANA Cloud ###
# Get plan for SAP HANA Cloud
data "btp_subaccount_service_plan" "hana_cloud" {
  subaccount_id = btp_subaccount.pbc_workshop.id
  offering_name = "hana-cloud"
  name          = "hana"
  depends_on    = [btp_subaccount_entitlement.hana_cloud]
}

# Create service instance
resource "btp_subaccount_service_instance" "hana_cloud" {
  subaccount_id  = btp_subaccount.pbc_workshop.id
  serviceplan_id = data.btp_subaccount_service_plan.hana_cloud.id
  name           = "my-hana-cloud-instance"
  depends_on     = [btp_subaccount_entitlement.hana_cloud]
  parameters = jsonencode(
    {
      "data" : {
        "memory" : 32,
        "edition" : "cloud",
        "systempassword" : "${var.hana_system_password}",
        "additionalWorkers" : 0,
        "disasterRecoveryMode" : "no_disaster_recovery",
        "enabledservices" : {
          "docstore" : false,
          "dpserver" : true,
          "scriptserver" : false
        },
        "requestedOperation" : {},
        "serviceStopped" : false,
        "slaLevel" : "standard",
        "storage" : 120,
        "vcpu" : 2,
        "whitelistIPs" : ["0.0.0.0/0"]
      }
  })

  timeouts = {
    create = "45m"
    update = "45m"
    delete = "45m"
  }
}

# Create service binding to SAP HANA Cloud service 
resource "btp_subaccount_service_binding" "hana_cloud" {
  subaccount_id       = btp_subaccount.pbc_workshop.id
  service_instance_id = btp_subaccount_service_instance.hana_cloud.id
  name                = "hana-cloud-key"
}


##########
### Roles
##########
resource "btp_subaccount_role_collection_assignment" "hana_cloud_admin" {
  subaccount_id        = btp_subaccount.pbc_workshop.id
  role_collection_name = "SAP HANA Cloud Administrator"
  user_name            = each.value
  for_each             = toset(var.admins)
  depends_on           = [btp_subaccount_subscription.hana_cloud_tools]
}

resource "btp_subaccount_role_collection_assignment" "bas_dev" {
  subaccount_id        = btp_subaccount.pbc_workshop.id
  role_collection_name = "Business_Application_Studio_Developer"
  for_each             = toset(var.developers)
  user_name            = each.value
  depends_on           = [btp_subaccount_subscription.bas]
}

resource "btp_subaccount_role_collection_assignment" "bas_admin" {
  subaccount_id        = btp_subaccount.pbc_workshop.id
  role_collection_name = "Business_Application_Studio_Administrator"
  for_each             = toset(var.admins)
  user_name            = each.value
  depends_on           = [btp_subaccount_subscription.bas]
}

resource "btp_subaccount_role_collection_assignment" "integration_suite" {
  subaccount_id        = btp_subaccount.pbc_workshop.id
  role_collection_name = "Integration_Provisioner"
  for_each             = toset(var.admins)
  user_name            = each.value
  depends_on           = [btp_subaccount_subscription.integration_suite]
}

resource "btp_subaccount_role_collection_assignment" "ailaunchpad_genai_manager" {
  subaccount_id        = btp_subaccount.pbc_workshop.id
  role_collection_name = "ailaunchpad_genai_manager"
  for_each             = toset(var.admins)
  user_name            = each.value
  depends_on           = [btp_subaccount_subscription.ai_launchpad]
}

resource "btp_subaccount_role_collection_assignment" "ailaunchpad_allow_all_resourcegroups" {
  subaccount_id        = btp_subaccount.pbc_workshop.id
  role_collection_name = "ailaunchpad_allow_all_resourcegroups"
  for_each             = toset(var.admins)
  user_name            = each.value
  depends_on           = [btp_subaccount_subscription.ai_launchpad]
}

resource "btp_subaccount_role_collection_assignment" "ailaunchpad_connections_editor" {
  subaccount_id        = btp_subaccount.pbc_workshop.id
  role_collection_name = "ailaunchpad_connections_editor"
  for_each             = toset(var.admins)
  user_name            = each.value
  depends_on           = [btp_subaccount_subscription.ai_launchpad]
}

resource "btp_subaccount_role_collection_assignment" "ailaunchpad_mloperations_editor" {
  subaccount_id        = btp_subaccount.pbc_workshop.id
  role_collection_name = "ailaunchpad_mloperations_editor"
  for_each             = toset(var.admins)
  user_name            = each.value
  depends_on           = [btp_subaccount_subscription.ai_launchpad]
}

resource "btp_subaccount_role_collection_assignment" "ailaunchpad_aicore_admin_editor" {
  subaccount_id        = btp_subaccount.pbc_workshop.id
  role_collection_name = "ailaunchpad_aicore_admin_editor"
  for_each             = toset(var.admins)
  user_name            = each.value
  depends_on           = [btp_subaccount_subscription.ai_launchpad]
}

resource "btp_subaccount_role_collection_assignment" "ailaunchpad_functions_explorer_editor_v2" {
  subaccount_id        = btp_subaccount.pbc_workshop.id
  role_collection_name = "ailaunchpad_functions_explorer_editor_v2"
  for_each             = toset(var.admins)
  user_name            = each.value
  depends_on           = [btp_subaccount_subscription.ai_launchpad]
}
