variable "vnet_config" {
  description = "Define vnet address space and other configurations"
  type        = map(string)
  default = {
    address_space = "10.0.0.0/16"
  }
}

variable "subnet_config" {
  description = "Define all subnets for the vnet deployed in default rg"
  type        = map(string)
  default = {
    default = "10.0.0.0/20"
    dev     = "10.0.16.0/20"
    test    = "10.0.32.0/20"
    prod    = "10.0.48.0/20"
  }
}

data "azuread_group" "godzilla" {
  display_name = "Team Godzilla"
}

data "azuread_group" "titanus" {
  display_name = "Team Titanus"
}

locals {
  godzilla_member_map = zipmap(
    range(length(data.azuread_group.godzilla.members)),
    data.azuread_group.godzilla.members
  )
  titanus_member_map = zipmap(
    range(length(data.azuread_group.titanus.members)),
    data.azuread_group.titanus.members
  )
}

locals {
  # TODO: These can be made variables depending on how we deploy
  region        = "Sweden Central"
  pretty-region = replace(lower(local.region), " ", "-")

  common_name = "${var.project.name}-${terraform.workspace}-${local.pretty-region}"

  common_tags = {
    owner              = lower(var.operations.name)
    department         = lower(var.department.name)
    department-manager = lower(var.department.manager)
    project            = lower(var.project.name)
    cost-center        = lower(var.project.cost-center)
    ops-team           = lower(var.operations.name)
    managed-by         = "terraform"
    environment        = terraform.workspace
    region             = local.pretty-region
  }
}
