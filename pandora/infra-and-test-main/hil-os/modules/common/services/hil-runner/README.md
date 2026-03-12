# HIL Runner

## Create runner

Runner creation in GitLab is handled by our Terraform setup.

To create a new runner, the file [gl_main.tf](../../../../../infrastructure/terraform/gl_main.tf) must be updated with a new `gitlab_user_runner` resource:

```tf
resource "gitlab_user_runner" "hil_gbg_01" {
  for_each    = (terraform.workspace == local.test_env ? { (terraform.workspace) = "" } : {})
  runner_type = "group_type"
  group_id    = var.gitlab_group_id
  tag_list    = var.gitlab_runner.hil_gbg_01_tags
  locked      = true
  description = "hil-gbg-01"
}
```

A tag list must also be created for the new runner.

### Tags

A runner needs tags so that a pipeline job can specify what type of runner it wants or be able to point to a specific one.\
Therefor each HIL runner needs its own unique set of tags.

The GitLab runner variables are specified in [gl_variables.tf](../../../../../infrastructure/terraform/gl_variables.tf).

```tf
variable "gitlab_runner" {
  description = "Describe runner configuration values for GitLab Runners"
  type        = any
  default = {
    service_account_name = "adaptio-ci-dev"
    cloud_runner_name    = "adaptio-gitlab-runner"
    cloud_runner_tags    = ["adaptio-k8-2"]
    hil_gbg_01_tags      = ["hil", "gbg", "hil-gbg-01"]
    log_level            = "info"
    log_format           = "runner"
  }
}
```

### Token

When the runner is created in GitLab, a token is generated for the runner service to use when registering with the GitLab instance.

The token shall be stored in our Azure key vault ([az_key_vault.tf](../../../../../infrastructure/terraform/az_key_vault.tf)).

```tf
resource "azurerm_key_vault_secret" "hil_gbg_01_runner_token" {
  for_each     = (terraform.workspace == local.test_env ? { (terraform.workspace) = "" } : {})
  key_vault_id = azurerm_key_vault.this[local.test_env].id
  name         = "hil-gbg-01-runner-token"
  value        = gitlab_user_runner.hil_gbg_01[local.test_env].token
}
```

The token must also be added to the SOPS secrets file ([secrets.yaml](../../../../../secrets.yaml)).
See [README](../../../../../README.md) for more information about how to edit the secrets file.

## Install and register the runner service

The HIL runner module shall be enabled by default in the nix configuration for all HIL-PC hosts.

### Authentication token

To install and register the runner service, the runner token must be available on the host system via an authentication token config file.

If the token has been added to the SOPS secrets file, our sops-nix configuration will ensure that the token is automatically added to the config file when the system is deployed.

### Enable the runner

Make sure the runner service is enabled in the applicable HIL-PC host configuration.

```nix
services.hil-runner = {
    enable = true;
    hilName = hilName;
};
```

### Update NixOS on the HIL-PC

See `hil-os` flake [README](../../../../README.md) for how to update the HIL-PC
