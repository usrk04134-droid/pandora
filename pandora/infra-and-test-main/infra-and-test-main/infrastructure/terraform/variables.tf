variable "department" {
  description = "Declare information related to the department"
  type        = map(string)
  default = {
    name    = "automation"
    id      = "N/A" # TODO: Find department ID
    manager = "cristiano.ferreira@esab.se"
  }
}

variable "project" {
  description = "Declare information related to the project"
  type        = map(string)
  default = {
    name        = "adaptio"
    id          = "N/A" # TODO: Find project ID
    manager     = "christer.lindgren@esab.se"
    cost-center = "300480"
  }
}

variable "operations" {
  description = "Declare information related to operations team"
  type        = map(string)
  default = {
    name    = "Team Godzilla"
    manager = "team-godzilla@esab.onmicrosoft.com"
  }
}

locals {
  # The values of below should be used for workspace names
  default_env = "default"
  dev_env     = "dev"
  test_env    = "test"
  prod_env    = "prod"
  gitlab_env  = "gitlab"
}
