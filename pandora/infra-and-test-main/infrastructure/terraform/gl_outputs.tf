# Find the GitLab subgroup "Adaptio Application Team"
data "gitlab_group" "adaptio" {
  count    = (terraform.workspace == local.gitlab_env ? 1 : 0)
  group_id = var.gitlab_group_id
}

# Find all projects under "Adaptio Application Team"
data "gitlab_projects" "adaptio_repos" {
  count             = (terraform.workspace == local.gitlab_env ? 1 : 0)
  group_id          = data.gitlab_group.adaptio[0].id
  order_by          = "name"
  include_subgroups = true
  archived          = false
}

# Convert List of Objects to a map with project ID as key
locals {
  adaptio_project_map = try({ for project in
  data.gitlab_projects.adaptio_repos[0].projects : project.id => project }, {})
}
