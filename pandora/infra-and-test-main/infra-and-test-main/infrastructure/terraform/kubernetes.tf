# Create Common namespace for Kubernetes
resource "kubernetes_namespace" "k8_dev_2" {
  for_each   = (terraform.workspace == local.gitlab_env ? { (terraform.workspace) = "" } : {})
  provider   = kubernetes.dev_2
  depends_on = [azurerm_kubernetes_cluster.dev_2]
  metadata {
    name = "gitlab-k8-dev"
  }
}

resource "kubernetes_secret" "gitlab_deploy_token_2" {
  for_each = (terraform.workspace == local.gitlab_env ? { (terraform.workspace) = "" } : {})
  provider = kubernetes.dev_2
  metadata {
    name      = "gitlab-registry-secret"
    namespace = kubernetes_namespace.nix_stored_2[local.gitlab_env].metadata[0].name
  }

  type = "kubernetes.io/dockerconfigjson"

  data = {
    ".dockerconfigjson" = jsonencode({
      auths = {
        "registry.gitlab.com" = {
          "username" = gitlab_deploy_token.nix_cache[local.gitlab_env].username
          "password" = gitlab_deploy_token.nix_cache[local.gitlab_env].token
          "email"    = var.operations.manager
          "auth"     = base64encode("${gitlab_deploy_token.nix_cache[local.gitlab_env].username}:${gitlab_deploy_token.nix_cache[local.gitlab_env].token}")
        }
      }
    })
  }
}

resource "kubernetes_namespace" "nix_stored_2" {
  for_each   = (terraform.workspace == local.gitlab_env ? { (terraform.workspace) = "" } : {})
  provider   = kubernetes.dev_2
  depends_on = [azurerm_kubernetes_cluster.dev_2]
  metadata {
    name = "nix-stored-gitlab"
  }
}
