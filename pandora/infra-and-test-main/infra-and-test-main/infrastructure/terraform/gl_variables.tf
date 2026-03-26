# This variables is fetched from the environment. Users Personal access token
# TODO: Check whether $GITLAB_TOKEN is set when running Terraform commands in CI/CD
variable "gitlab_token" {
  description = "GitLab token for the GitLab Terraform provider"
  type        = string
}

variable "gitlab_group_id" {
  description = "GitLab Group ID for parent group Adaptio Application Team"
  type        = string
  default     = "63354310"
}

variable "gitlab_plc_group_id" {
  description = "GitLab Group ID for the PLC sub group"
  type        = string
  default     = "97690313"
}

variable "gitlab_infra_project_id" {
  description = "GitLab project ID for infra-and-test project"
  type        = string
  default     = "59026355"
}

variable "gitlab_runner" {
  description = "Describe runner configuration values for GitLab Runners"
  type        = any
  default = {
    service_account_name       = "adaptio-ci-dev"
    service_account_name_small = "adaptio-ci-dev-small"
    cloud_runner_name_2        = "adaptio-gitlab-runner-2"
    cloud_runner_tags_2        = ["adaptio-k8-2", "biggie"]
    cloud_runner_tags_2_small  = ["adaptio-k8-2-small", "smalls"]
    hil_gbg_01_tags            = ["hil", "gbg", "hil-gbg-01"]
    hil_gbg_02_tags            = ["hil", "gbg", "hil-gbg-02"]
    hil_chn_01_tags            = ["hil", "chn", "hil-chn-01"]
    log_level                  = "info"
    log_format                 = "runner"
  }
}

locals {
  mechagodzilla_user_id = "23155031"
}
