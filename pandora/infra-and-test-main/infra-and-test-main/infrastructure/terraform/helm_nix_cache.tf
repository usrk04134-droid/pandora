# TODO Replace with a proper SSL supported nginx ingress and add proper network policy
# Service abstraction, forwarding between the gitlab and stored namespaces
resource "kubernetes_service" "gitlab_nix_stored_2" {
  for_each   = (terraform.workspace == local.gitlab_env ? { (terraform.workspace) = "" } : {})
  provider   = kubernetes.dev_2
  depends_on = [kubernetes_namespace.k8_dev_2, helm_release.nix_stored_2]
  metadata {
    name      = "nix-cache"
    namespace = kubernetes_namespace.k8_dev_2[local.gitlab_env].metadata[0].name
  }

  spec {
    type = "ExternalName"
    external_name = join(".", [helm_release.nix_stored_2[local.gitlab_env].name,
      kubernetes_namespace.nix_stored_2[local.gitlab_env].metadata[0].name,
      "svc.cluster.local"
      ]
    )
  }
}

resource "kubernetes_manifest" "sc_azureblob_fuse2_public_2" {
  for_each = (terraform.workspace == local.gitlab_env ? { (terraform.workspace) = "" } : {})
  provider = kubernetes.dev_2
  manifest = {
    apiVersion  = "storage.k8s.io/v1"
    kind        = "StorageClass"
    metadata    = { name = "azureblob-fuse2-public-2" }
    provisioner = "blob.csi.azure.com"
    parameters = {
      protocol = "fuse2"
      skuName  = "Premium_LRS"
    }
    reclaimPolicy        = "Delete"
    volumeBindingMode    = "Immediate"
    allowVolumeExpansion = true
  }
}

resource "kubernetes_persistent_volume_claim" "nix_blob_pvc_2" {
  for_each = (terraform.workspace == local.gitlab_env ? { (terraform.workspace) = "" } : {})
  provider = kubernetes.dev_2
  metadata {
    name      = "pvc-nix-blob"
    namespace = kubernetes_namespace.nix_stored_2[local.gitlab_env].metadata[0].name
  }
  wait_until_bound = false

  spec {
    access_modes       = ["ReadWriteMany"]
    storage_class_name = "azureblob-fuse2-public-2"
    resources { requests = { storage = "1Ti" } }
  }
}

# Configure nix binary cache service using Helm
resource "helm_release" "nix_stored_2" {
  for_each   = (terraform.workspace == local.gitlab_env ? { (terraform.workspace) = "" } : {})
  provider   = helm.dev_2
  depends_on = [azurerm_kubernetes_cluster.dev_2]
  name       = "nix-stored"
  chart      = "../helm/nix-stored"
  lint       = true
  namespace  = kubernetes_namespace.nix_stored_2[local.gitlab_env].metadata[0].name

  set = [
    {
      name  = "nodeSelector.kubernetes\\.azure\\.com/agentpool"
      value = "runnerpool"
    },
    {
      name  = "imagePullSecrets.name"
      value = kubernetes_secret.gitlab_deploy_token_2[local.gitlab_env].metadata[0].name
    },
    {
      name  = "persistence.enabled"
      value = "true"
    },
    {
      name  = "persistence.existingClaim"
      value = kubernetes_persistent_volume_claim.nix_blob_pvc_2[local.gitlab_env].metadata[0].name
    },
    {
      name  = "persistence.mountPath"
      value = "/var/lib/nixStored"
    },
    {
      name  = "env[0].name"
      value = "NIX_STORED_PATH"
    },
    {
      name  = "env[0].value"
      value = "/var/lib/nixStored"
    }
  ]
}
