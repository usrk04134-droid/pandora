/*
This file configures defines all the providers necessary for our infrastructure
and the necessary provider specific configuration.

Variables used within this file come from the variables.tf file located at the
root of infrastructure directory
 */

terraform {
  backend "azurerm" {
    /*
      These values need to be fetched from Azure or default tfstate.
      Because we cannot dynamically assign in backend block
       */
    resource_group_name  = "rg-adaptio-default-sweden-central"
    storage_account_name = "st1adaptiodefault"
    container_name       = "tfstate"
    key                  = "terraform.tfstate"
  }
  required_providers {
    gitlab = {
      source  = "gitlabhq/gitlab"
      version = "18.1.1"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "4.34.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "3.4.0"
    }
    http = {
      source  = "hashicorp/http"
      version = "3.4.3"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.6.2"
    }
    local = {
      source  = "hashicorp/local"
      version = "2.5.1"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "4.0.5"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.37.1"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "3.0.2"
    }
  }
}

provider "gitlab" {
  token = var.gitlab_token
}

provider "azurerm" {

  /*
  Using default behavior for "features", see link below for all blocks:
  https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/guides/features-block
   */
  features {}

}

provider "azuread" {
  # Configuration options
}


/*
All resources below need to be created after resources from default have been
created. CHICKEN AND EGG PROBLEM!

Values for terraform backend config need to be fetched from the terraform
backend section (scroll up)
 */
locals {
  backend_config = {
    resource_group_name  = "rg-adaptio-default-sweden-central"
    storage_account_name = "st1adaptiodefault"
    container_name       = "tfstate"
    key                  = "terraform.tfstate"
  }
}
data "terraform_remote_state" "default" {
  backend = "azurerm"

  config    = local.backend_config
  workspace = "default"
}

data "terraform_remote_state" "dev" {
  backend   = "azurerm"
  config    = local.backend_config
  workspace = "dev"
}

data "terraform_remote_state" "test" {
  backend   = "azurerm"
  config    = local.backend_config
  workspace = "test"
}

provider "kubernetes" {
  alias                  = "dev_2"
  host                   = data.terraform_remote_state.dev.outputs.dev_cluster_2_kube_config.host
  client_certificate     = base64decode(data.terraform_remote_state.dev.outputs.dev_cluster_2_kube_config.client_certificate)
  client_key             = base64decode(data.terraform_remote_state.dev.outputs.dev_cluster_2_kube_config.client_key)
  cluster_ca_certificate = base64decode(data.terraform_remote_state.dev.outputs.dev_cluster_2_kube_config.cluster_ca_certificate)
}

provider "helm" {
  alias = "dev_2"
  kubernetes = {
    host                   = data.terraform_remote_state.dev.outputs.dev_cluster_2_kube_config.host
    client_certificate     = base64decode(data.terraform_remote_state.dev.outputs.dev_cluster_2_kube_config.client_certificate)
    client_key             = base64decode(data.terraform_remote_state.dev.outputs.dev_cluster_2_kube_config.client_key)
    cluster_ca_certificate = base64decode(data.terraform_remote_state.dev.outputs.dev_cluster_2_kube_config.cluster_ca_certificate)
  }
}
