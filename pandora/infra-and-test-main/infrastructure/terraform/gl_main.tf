resource "gitlab_user_runner" "adaptio_dev_2" {
  for_each    = (terraform.workspace == local.gitlab_env ? { (terraform.workspace) = "" } : {})
  runner_type = "group_type"
  group_id    = var.gitlab_group_id
  tag_list    = var.gitlab_runner.cloud_runner_tags_2
  locked      = true
}

resource "gitlab_user_runner" "adaptio_dev_2_smalls" {
  for_each    = (terraform.workspace == local.gitlab_env ? { (terraform.workspace) = "" } : {})
  runner_type = "group_type"
  group_id    = var.gitlab_group_id
  tag_list    = var.gitlab_runner.cloud_runner_tags_2_small
  locked      = true
}


resource "gitlab_user_runner" "hil_gbg_01" {
  for_each    = (terraform.workspace == local.test_env ? { (terraform.workspace) = "" } : {})
  runner_type = "group_type"
  group_id    = var.gitlab_group_id
  tag_list    = var.gitlab_runner.hil_gbg_01_tags
  locked      = true
  description = "hil-gbg-01"
}

resource "gitlab_user_runner" "hil_gbg_02" {
  for_each    = (terraform.workspace == local.test_env ? { (terraform.workspace) = "" } : {})
  runner_type = "group_type"
  group_id    = var.gitlab_group_id
  tag_list    = var.gitlab_runner.hil_gbg_02_tags
  locked      = true
  description = "hil-gbg-02"
}

resource "gitlab_user_runner" "hil_chn_01" {
  for_each    = (terraform.workspace == local.test_env ? { (terraform.workspace) = "" } : {})
  runner_type = "group_type"
  group_id    = var.gitlab_group_id
  tag_list    = var.gitlab_runner.hil_chn_01_tags
  locked      = true
  description = "hil-chn-01"
}

resource "random_pet" "deploy_token_name" {
  for_each = (terraform.workspace == local.gitlab_env ? { (terraform.workspace) = "" } : {})
  length   = 1
  prefix   = "godzilla"
}

resource "gitlab_deploy_token" "nix_cache" {
  for_each = (terraform.workspace == local.gitlab_env ? { (terraform.workspace) = "" } : {})
  project  = var.gitlab_infra_project_id
  name     = random_pet.deploy_token_name[local.gitlab_env].id
  username = random_pet.deploy_token_name[local.gitlab_env].id
  scopes   = ["read_registry"]
}

resource "gitlab_group_variable" "nix_cache_signing_key" {
  for_each      = (terraform.workspace == local.dev_env ? { (terraform.workspace) = "" } : {})
  depends_on    = [data.azurerm_key_vault_secret.nix_cache_signing_key]
  description   = "nix cache signing key file for the cache service in kubernetes"
  group         = var.gitlab_group_id
  key           = "NIX_CACHE_SIGNING_KEY_FILE"
  value         = data.azurerm_key_vault_secret.nix_cache_signing_key[local.dev_env].value
  variable_type = "file"
  masked        = true
  raw           = true

  provisioner "local-exec" {
    command = "echo 'NOTE: The GitLab terraform provider does NOT support setting hidden=true on group variables'"
  }
}

resource "gitlab_group_variable" "nix_cache_public_key" {
  for_each    = (terraform.workspace == local.dev_env ? { (terraform.workspace) = "" } : {})
  depends_on  = [data.azurerm_key_vault_secret.nix_cache_public_key]
  description = "nix cache public verification key for the cache service in kubernetes"
  group       = var.gitlab_group_id
  key         = "NIX_CACHE_PUB_KEY"
  value       = data.azurerm_key_vault_secret.nix_cache_public_key[local.dev_env].value
  raw         = true
}

resource "gitlab_group_variable" "nix_cache_url" {
  for_each    = (terraform.workspace == local.gitlab_env ? { (terraform.workspace) = "" } : {})
  depends_on  = [helm_release.nix_stored_2]
  description = "nix cache local url for the kubernetes cluster"
  group       = var.gitlab_group_id
  key         = "NIX_CACHE_URL"
  value       = "http://${kubernetes_service.gitlab_nix_stored_2[local.gitlab_env].metadata[0].name}"
  raw         = true
}

resource "gitlab_group_variable" "nix_cache_build_hook_script" {
  for_each      = (terraform.workspace == local.gitlab_env ? { (terraform.workspace) = "" } : {})
  description   = "nix cache post build hook script file to push to cache service in kubernetes"
  group         = var.gitlab_group_id
  key           = "NIX_CACHE_BUILD_HOOK_FILE"
  value         = <<-EOF
    #!/bin/sh
    set -euf
    export IFS=' '
    exec nix copy --verbose --to $NIX_CACHE_URL $OUT_PATHS
  EOF
  variable_type = "file"
  raw           = true
}

resource "gitlab_group_variable" "hil_cache_build_hook_script" {
  for_each      = (terraform.workspace == local.gitlab_env ? { (terraform.workspace) = "" } : {})
  description   = "nix cache post build hook script file to push to cache service in HIL pc"
  group         = var.gitlab_group_id
  key           = "HIL_CACHE_BUILD_HOOK_FILE"
  value         = <<-EOF
    #!/bin/sh
    set -euf
    export IFS=' '
    exec nix copy --verbose --to $HIL_CACHE_URL $OUT_PATHS
  EOF
  variable_type = "file"
  raw           = true
}

resource "gitlab_group_variable" "gitlab_shared_functions" {
  for_each      = (terraform.workspace == local.gitlab_env ? { (terraform.workspace) = "" } : {})
  description   = "shared bash functions used by gitlab pipelines"
  group         = var.gitlab_group_id
  key           = "GITLAB_SHARED_FUNCS"
  value         = <<-EOF
    [[ -z "$${BOLD+x}" ]] && readonly BOLD="\x1b[1m"
    [[ -z "$${BLUE+x}" ]] && readonly BLUE="\x1b[94m"
    [[ -z "$${RED+x}" ]] && readonly RED="\x1b[91m"
    [[ -z "$${GREEN+x}" ]] && readonly GREEN="\x1b[92m"
    [[ -z "$${YELLOW+x}" ]] && readonly YELLOW="\x1b[93m"
    [[ -z "$${RESET+x}" ]] && readonly RESET="\x1b[0m"

    # function for starting a collapsible section
    # $1 - Section title. String REQUIRED
    # $2 - Section description. String
    # $3 - Optional flag to start collapsed.
    function section_start () {
      local section_title="$${1}"
      local section_description="$${2:-$section_title}"
      local section_collapsed="$${3:+true}"
      : $${section_collapsed:=false}

      echo -e "section_start:$(date +%s):$${section_title}[collapsed=$${section_collapsed}]\r\033[0K$${section_description}"
    }

    # Function for ending a collapsible section
    # $1 - Section title, SHALL match what was used with section_start(). String REQUIRED
    function section_end () {
      local section_title="$${1}"

      echo -e "section_end:$(date +%s):$${section_title}\r\033[0K"
    }

    # Function for logging. Using stderr to not interfere with output on stdout.
    function log() {
      local timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
      local level="$${1}"
      local message="$${2}"
      local color="$${3}"

      echo -e "$${BLUE}[$${timestamp}]$${RESET} $${color}$${BOLD}$${level}$${RESET} $${message}" >&2
    }

    function log_info() {
      log "INFO" "$${1}" "$${GREEN}"
    }

    function log_warn() {
      log "WARN" "$${1}" "$${YELLOW}"
    }

    function log_error() {
      log "ERROR" "$${1}" "$${RED}"
    }

    function log_debug() {
      log "DEBUG" "$${1}" "$${BLUE}"
    }

  EOF
  variable_type = "file"
  raw           = true
}

resource "gitlab_group_variable" "pushgateway_url" {
  for_each    = (terraform.workspace == local.gitlab_env ? { (terraform.workspace) = "" } : {})
  description = "Pushgateway URL for the Kubernetes cluster"
  group       = var.gitlab_group_id
  key         = "PUSHGATEWAY_URL"
  value       = "https://pushgateway.k3s.in"
  raw         = true
}

resource "gitlab_branch_protection" "default_branches" {
  for_each                     = (terraform.workspace == local.gitlab_env ? local.adaptio_project_map : {})
  project                      = each.key
  branch                       = "main"
  push_access_level            = "no one"
  merge_access_level           = "developer"
  unprotect_access_level       = "maintainer"
  code_owner_approval_required = true
  allowed_to_push {
    user_id = local.mechagodzilla_user_id
  }
}

resource "gitlab_branch_protection" "release_branches" {
  for_each                     = (terraform.workspace == local.gitlab_env ? local.adaptio_project_map : {})
  project                      = each.key
  branch                       = "release/*"
  push_access_level            = "no one"
  merge_access_level           = "developer"
  unprotect_access_level       = "maintainer"
  code_owner_approval_required = true
  allowed_to_push {
    user_id = local.mechagodzilla_user_id
  }
}

resource "gitlab_branch_protection" "gen2_branch" {
  for_each                     = (terraform.workspace == local.gitlab_env ? local.adaptio_project_map : {})
  project                      = each.key
  branch                       = "gen2"
  push_access_level            = "no one"
  merge_access_level           = "developer"
  unprotect_access_level       = "maintainer"
  code_owner_approval_required = true
  allowed_to_push {
    user_id = local.mechagodzilla_user_id
  }
}

resource "gitlab_tag_protection" "this" {
  for_each            = (terraform.workspace == local.gitlab_env ? local.adaptio_project_map : {})
  create_access_level = "maintainer"
  project             = each.key
  tag                 = "*"
}

resource "gitlab_branch" "release_lp0" {
  for_each = (terraform.workspace == local.gitlab_env ? local.adaptio_project_map : {})
  project  = each.key
  name     = "release/lp0"
  ref      = "main"
}

resource "gitlab_branch" "release_lp1" {
  for_each = (terraform.workspace == local.gitlab_env ? local.adaptio_project_map : {})
  project  = each.key
  name     = "release/lp1"
  ref      = "main"
}

resource "gitlab_branch" "release_lp2" {
  for_each = (terraform.workspace == local.gitlab_env ? local.adaptio_project_map : {})
  project  = each.key
  name     = "release/lp2.0"
  ref      = "main"
}

resource "gitlab_branch" "release_lp3" {
  for_each = (terraform.workspace == local.gitlab_env ? local.adaptio_project_map : {})
  project  = each.key
  name     = "release/lp3.0"
  ref      = "main"
}

resource "gitlab_branch" "release_lp4" {
  for_each = (terraform.workspace == local.gitlab_env ? local.adaptio_project_map : {})
  project  = each.key
  name     = "release/lp4.0"
  ref      = "main"
}

resource "gitlab_branch" "gen2" {
  for_each = (terraform.workspace == local.gitlab_env ? local.adaptio_project_map : {})
  project  = each.key
  name     = "gen2"
  ref      = "main"
}

resource "gitlab_project_push_rules" "push_rules" {
  for_each               = (terraform.workspace == local.gitlab_env ? local.adaptio_project_map : {})
  project                = each.key
  commit_committer_check = true # Require verified emails
  member_check           = true
  deny_delete_tag        = true
}

resource "random_pet" "flake_access_token_name" {
  for_each = (terraform.workspace == local.gitlab_env ? { (terraform.workspace) = "" } : {})
  length   = 1
  prefix   = "godzilla"
}

resource "gitlab_group_access_token" "flake_repo_token" {
  for_each     = (terraform.workspace == local.gitlab_env ? { (terraform.workspace) = "" } : {})
  group        = var.gitlab_group_id
  name         = random_pet.flake_access_token_name[local.gitlab_env].id
  expires_at   = "2026-12-11"
  access_level = "developer"
  scopes       = ["api", "read_repository"]
}

resource "gitlab_group_variable" "flake_config_pat" {
  for_each    = (terraform.workspace == local.gitlab_env ? { (terraform.workspace) = "" } : {})
  description = "Token used by flake inputs in gitlab pipelines"
  group       = var.gitlab_group_id
  key         = "NIX_CONFIG"
  value       = "access-tokens = gitlab.com=PAT:${gitlab_group_access_token.flake_repo_token[local.gitlab_env].token}"
  masked      = false
  raw         = true

  provisioner "local-exec" {
    command = "echo 'NOTE: The GitLab terraform provider does NOT support setting hidden=true on group variables'"
  }
}

resource "gitlab_group_variable" "gitlab_service_account_pat" {
  for_each    = (terraform.workspace == local.dev_env ? { (terraform.workspace) = "" } : {})
  description = "PAT of our Team Godzillas service account bot (Mechagodzilla) on GitLab"
  group       = var.gitlab_group_id
  key         = "SERVICE_ACCOUNT_PAT"
  value       = data.azurerm_key_vault_secret.gitlab_service_account_pat[local.dev_env].value
  masked      = true
  raw         = true
}

resource "gitlab_group_variable" "plc_apax_token" {
  for_each    = (terraform.workspace == local.dev_env ? { (terraform.workspace) = "" } : {})
  description = "PLC development token for use with Apax"
  group       = var.gitlab_plc_group_id
  key         = "PLC_APAX_TOKEN"
  value       = data.azurerm_key_vault_secret.plc_apax_token[local.dev_env].value
  masked      = true
  raw         = true
}

resource "gitlab_group_variable" "testzilla_testrail_api_key" {
  for_each    = (terraform.workspace == local.dev_env ? { (terraform.workspace) = "" } : {})
  description = "Testzilla users Testrail API Key"
  group       = var.gitlab_group_id
  key         = "TESTZILLA_TESTRAIL_API_KEY"
  value       = data.azurerm_key_vault_secret.testzilla_testrail_api_key[local.dev_env].value
  masked      = true
  raw         = true
}

resource "gitlab_project" "project_configuration" {
  for_each                                         = (terraform.workspace == local.gitlab_env ? local.adaptio_project_map : {})
  name                                             = each.value.name
  merge_method                                     = "rebase_merge"
  merge_pipelines_enabled                          = false
  only_allow_merge_if_all_discussions_are_resolved = true
  only_allow_merge_if_pipeline_succeeds            = true
  printing_merge_request_link_enabled              = true
  remove_source_branch_after_merge                 = true
  resolve_outdated_diff_discussions                = false
  squash_option                                    = "never"

  container_expiration_policy {
    enabled           = true
    cadence           = "1d"
    keep_n            = 5
    older_than        = "14d"
    name_regex_delete = "^\\d+\\.\\d+\\.\\d+-.*$"
    name_regex_keep   = "^\\d+\\.\\d+\\.\\d+$"
  }
}

resource "gitlab_project_approval_rule" "any_approver" {
  for_each           = (terraform.workspace == local.gitlab_env ? local.adaptio_project_map : {})
  project            = each.key
  approvals_required = 1
  name               = "All Members"
  rule_type          = "any_approver"
}

resource "gitlab_project_level_mr_approvals" "mr_approvals" {
  for_each                                       = (terraform.workspace == local.gitlab_env ? local.adaptio_project_map : {})
  project                                        = each.key
  disable_overriding_approvers_per_merge_request = false
  merge_requests_author_approval                 = true
  merge_requests_disable_committers_approval     = false
  reset_approvals_on_push                        = true
}
