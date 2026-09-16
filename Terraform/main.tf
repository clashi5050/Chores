# =============================================================================
# main.tf
# -----------------------------------------------------------------------------
# Static Terraform config. No runtime templating: every environment-specific
# value arrives through variables (rendered into nonsecret.auto.tfvars from the
# JSON matrix) and the backend is configured via -backend-config flags on
# `terraform init`. This avoids the fragile eval/echo templating and is the
# recommended way to parameterize remote state.
# =============================================================================

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }

  # Partial backend config. Storage account/container/resource group are fixed
  # in backend.hcl (committed) so they don't need to be re-supplied each time.
  # `key` still varies per environment/region/app and is passed at init time:
  #   terraform init -backend-config=backend.hcl \
  #     -backend-config="key=${environment}-${short_loc}-${app}-static-web-app.tfstate"
  # The app name is included so this doesn't collide with other static-web-app
  # deployments (e.g. star-squad-bundle) sharing the same remote state storage.
  backend "azurerm" {
    use_oidc = true
  }
}

provider "azurerm" {
  features {}

  use_oidc        = true
  client_id       = var.arm_client_id
  subscription_id = var.arm_subscription_id
  tenant_id       = var.arm_tenant_id
}

locals {
  # Naming convention: <company_loc>-<app>-<type>-<environment>-<short_loc>
  # e.g. use2-chores-swa-main-use2
  name_prefix = "${var.company_loc}-${var.app}-${var.type}-${var.environment}-${var.short_loc}"

  # Storage account names must be globally unique, lowercase alphanumeric
  # only, and <=24 chars, so they can't use the dash-separated name_prefix.
  storage_account_name = substr(lower(replace("st${local.name_prefix}", "-", "")), 0, 24)

  common_tags = {
    environment = var.environment
    app         = var.app
    type        = var.type
    location    = var.location
    managed-by  = "terraform"
    repo        = "Chores"
    pattern     = "static-web-app"
  }
}

# -----------------------------------------------------------------------------
# Resource Group dedicated to this Static Web App
# -----------------------------------------------------------------------------
resource "azurerm_resource_group" "swa" {
  name     = "rg-${local.name_prefix}"
  location = var.location
  tags     = local.common_tags
}

# -----------------------------------------------------------------------------
# Shared state store for the Chore Wars API (Managed Functions running on the
# Static Web App below). A single Table Storage row holds the whole app state
# as JSON, read/written via the entity's ETag for optimistic concurrency so
# two phones writing at once don't silently clobber each other.
# -----------------------------------------------------------------------------
resource "azurerm_storage_account" "state" {
  name                     = local.storage_account_name
  resource_group_name      = azurerm_resource_group.swa.name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  tags = local.common_tags
}

resource "azurerm_storage_table" "state" {
  name                 = "chorestate"
  storage_account_name = azurerm_storage_account.state.name
}

# Shared household PIN, generated once and used by the API to authorize
# GET/POST /api/state requests (no user accounts — see api/src/lib/auth.js).
# Retrieve it after apply with `terraform output -raw household_pin`.
resource "random_password" "household_pin" {
  length  = 6
  numeric = true
  lower   = false
  upper   = false
  special = false
}

# -----------------------------------------------------------------------------
# Azure Static Web App (Free tier)
# Content is deployed separately via the static-web-app-deploy workflow using
# the deployment API token. Terraform only provisions the resource here.
# app_settings feeds the co-located Managed Functions API (apps/chores/api)
# its storage connection info and the household PIN.
# -----------------------------------------------------------------------------
resource "azurerm_static_web_app" "app" {
  name                = "swa-${local.name_prefix}"
  resource_group_name = azurerm_resource_group.swa.name

  # Static Web Apps Free tier is only available in a subset of regions.
  # Override var.location via the JSON input if the region is not supported.
  location = var.location

  sku_tier = "Free"
  sku_size = "Free"

  app_settings = {
    AZURE_STORAGE_CONNECTION_STRING = azurerm_storage_account.state.primary_connection_string
    STATE_TABLE_NAME                = azurerm_storage_table.state.name
    HOUSEHOLD_PIN                   = random_password.household_pin.result
  }

  tags = local.common_tags
}