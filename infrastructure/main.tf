terraform {
  required_version = ">= 1.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>3.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~>3.1"
    }
  }
}

provider "azurerm" {
  features {}
}

# Random string for unique naming
resource "random_string" "main" {
  length  = 8
  special = false
  upper   = false
}

# Data source for current Azure client configuration
data "azurerm_client_config" "current" {}

# Resource Group
resource "azurerm_resource_group" "main" {
  name     = "rg-chatapp-${random_string.main.result}"
  location = var.location

  tags = {
    Environment = var.environment
    Project     = "azure-chat-app"
    CreatedBy   = "terraform"
  }
}

# Azure Kubernetes Service
resource "azurerm_kubernetes_cluster" "main" {
  name                = "aks-chatapp-${random_string.main.result}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  dns_prefix          = "akschatapp${random_string.main.result}"

  default_node_pool {
    name       = "default"
    node_count = var.node_count
    vm_size    = var.vm_size
    
    tags = {
      Environment = var.environment
      Project     = "azure-chat-app"
      CreatedBy   = "terraform"
    }
  }

  identity {
    type = "SystemAssigned"
  }

  tags = {
    Environment = var.environment
    Project     = "azure-chat-app"
    CreatedBy   = "terraform"
  }
}

# Azure Cache for Redis
resource "azurerm_redis_cache" "main" {
  name                = "redis-chatapp-${random_string.main.result}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  capacity            = 0
  family              = "C"
  sku_name            = "Basic"
  minimum_tls_version = "1.2"

  redis_configuration {
  }

  tags = {
    Environment = var.environment
    Project     = "azure-chat-app"
    CreatedBy   = "terraform"
  }
}

# Cognitive Services Account for Azure OpenAI
resource "azurerm_cognitive_account" "openai" {
  name                = "openai-chatapp-${random_string.main.result}"
  location            = var.openai_location
  resource_group_name = azurerm_resource_group.main.name
  kind                = "OpenAI"
  sku_name            = "S0"

  tags = {
    Environment = var.environment
    Project     = "azure-chat-app"
    CreatedBy   = "terraform"
  }
}

# Azure OpenAI Model Deployment
resource "azurerm_cognitive_deployment" "gpt" {
  name                 = "gpt-4o-mini"
  cognitive_account_id = azurerm_cognitive_account.openai.id

  model {
    format  = "OpenAI"
    name    = "gpt-4o-mini"
    version = "2024-07-18"
  }

  scale {
    type     = "Standard"
    capacity = 1
  }
}

# Container Registry
resource "azurerm_container_registry" "main" {
  name                = "acrchatapp${random_string.main.result}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku                 = "Basic"
  admin_enabled       = true

  tags = {
    Environment = var.environment
    Project     = "azure-chat-app"
    CreatedBy   = "terraform"
  }
}

# Role assignment for AKS to pull from ACR
resource "azurerm_role_assignment" "acr_pull" {
  principal_id                     = azurerm_kubernetes_cluster.main.kubelet_identity[0].object_id
  role_definition_name             = "AcrPull"
  scope                           = azurerm_container_registry.main.id
  skip_service_principal_aad_check = true
}
