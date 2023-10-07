terraform {
  required_providers {
    azurerm = {
      version = "~> 3.54.0"
      source  = "hashicorp/azurerm"
    }
    random = {
      version = "3.5.1"
      source = "hashicorp/random"
    }
  }
  required_version = ">= 1.0"
}

provider "azurerm" {
  features {
  }

  tenant_id       = var.tenant_id
  subscription_id = var.subscription_id
}


variable "tenant_id" {
  type = string
}

variable "subscription_id" {
  type = string
}