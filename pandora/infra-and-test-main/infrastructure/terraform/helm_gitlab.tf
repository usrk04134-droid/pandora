resource "helm_release" "gitlab_runner_2" {
  for_each   = (terraform.workspace == local.gitlab_env ? { (terraform.workspace) = "" } : {})
  provider   = helm.dev_2
  name       = "gitlab-runner"
  repository = "http://charts.gitlab.io"
  chart      = "gitlab-runner"
  version    = "0.80.0"
  namespace  = kubernetes_namespace.k8_dev_2[local.gitlab_env].metadata[0].name
  values = [
    yamlencode({
      image = {
        registry = "registry.gitlab.com"
        image    = "gitlab-org/gitlab-runner"
      }
      useTini             = false
      imagePullPolicy     = "IfNotPresent"
      probeTimeoutSeconds = 4
      livenessProbe = {
        initialDelaySeconds = 60
        periodSeconds       = 10
        successThreshold    = 1
        failureThreshold    = 3
      }
      readinessProbe = {
        initialDelaySeconds = 60
        periodSeconds       = 10
        successThreshold    = 1
        failureThreshold    = 3
      }
      replicas                      = 2
      revisionHistoryLimit          = 10
      gitlabUrl                     = "https://gitlab.com/"
      runnerToken                   = gitlab_user_runner.adaptio_dev_2[local.gitlab_env].token
      unregisterRunners             = true
      terminationGracePeriodSeconds = 3600
      certsSecretName               = ""
      concurrent                    = 5
      shutdown_timeout              = 0
      checkInterval                 = 3
      logLevel                      = var.gitlab_runner.log_level
      logFormat                     = var.gitlab_runner.log_format
      rbac = {
        create                      = true
        generatedServiceAccountName = ""
        rules                       = []
        clusterWideAccess           = false
        serviceAccountAnnotations   = {}
        imagePullSecrets            = []
      }
      serviceAccount = {
        create           = true
        name             = var.gitlab_runner.service_account_name
        annotations      = {}
        imagePullSecrets = []
      }
      runners = {
        name     = var.gitlab_runner.cloud_runner_name_2
        executor = "kubernetes"
        config   = <<EOF
          [[runners]]
            environment = ["NIX_BUILD_CORES=0", "CMAKE_BUILD_PARALLEL_LEVEL=8", "MAKEFLAGS=-j8", "CTEST_PARALLEL_LEVEL=8"]
            output_limit = 12288
            [runners.kubernetes]
              namespace = "${kubernetes_namespace.k8_dev_2[local.gitlab_env].metadata[0].name}"
              image = "alpine"
              privileged = true
              poll_timeout = 360
              cpu_limit = "12"
              memory_limit = "24Gi"
              cpu_request = "6"
              memory_request = "12Gi"
              [runners.kubernetes.node_selector]
                role = "worker"
                environment = "gitlab"
                size = "big"
            [runners.cache]
              Type = "azure"
              Path = "runner_cache"
              Shared = false
              [runners.cache.azure]
                AccountName = "${data.terraform_remote_state.dev.outputs.gl_runner_st_name}"
                AccountKey = "${data.terraform_remote_state.dev.outputs.gl_runner_st_key}"
                ContainerName = "${data.terraform_remote_state.dev.outputs.gl_runner_cache_container_name}"
                StorageDomain = "blob.core.windows.net"
        EOF
      }
      podSecurityContext = {
        runAsUser = 100
        fsGroup   = 65533
      }
      nodeSelector = {
        role        = "manager"
        environment = "gitlab"
      }
    })
  ]
}

resource "helm_release" "gitlab_runner_2_smalls" {
  for_each   = (terraform.workspace == local.gitlab_env ? { (terraform.workspace) = "" } : {})
  provider   = helm.dev_2
  name       = "gitlab-runner-small"
  repository = "http://charts.gitlab.io"
  chart      = "gitlab-runner"
  version    = "0.80.0"
  namespace  = kubernetes_namespace.k8_dev_2[local.gitlab_env].metadata[0].name
  values = [
    yamlencode({
      image = {
        registry = "registry.gitlab.com"
        image    = "gitlab-org/gitlab-runner"
      }
      useTini             = false
      imagePullPolicy     = "IfNotPresent"
      probeTimeoutSeconds = 4
      livenessProbe = {
        initialDelaySeconds = 60
        periodSeconds       = 10
        successThreshold    = 1
        failureThreshold    = 3
      }
      readinessProbe = {
        initialDelaySeconds = 60
        periodSeconds       = 10
        successThreshold    = 1
        failureThreshold    = 3
      }
      replicas                      = 2
      revisionHistoryLimit          = 10
      gitlabUrl                     = "https://gitlab.com/"
      runnerToken                   = gitlab_user_runner.adaptio_dev_2_smalls[local.gitlab_env].token
      unregisterRunners             = true
      terminationGracePeriodSeconds = 3600
      certsSecretName               = ""
      concurrent                    = 5
      shutdown_timeout              = 0
      checkInterval                 = 3
      logLevel                      = var.gitlab_runner.log_level
      logFormat                     = var.gitlab_runner.log_format
      rbac = {
        create                      = true
        generatedServiceAccountName = ""
        rules                       = []
        clusterWideAccess           = false
        serviceAccountAnnotations   = {}
        imagePullSecrets            = []
      }
      serviceAccount = {
        create           = true
        name             = var.gitlab_runner.service_account_name_small
        annotations      = {}
        imagePullSecrets = []
      }
      runners = {
        name     = var.gitlab_runner.cloud_runner_name_2
        executor = "kubernetes"
        config   = <<EOF
          [[runners]]
            environment = ["NIX_BUILD_CORES=0", "CMAKE_BUILD_PARALLEL_LEVEL=8", "MAKEFLAGS=-j8", "CTEST_PARALLEL_LEVEL=8"]
            output_limit = 12288
            [runners.kubernetes]
              namespace = "${kubernetes_namespace.k8_dev_2[local.gitlab_env].metadata[0].name}"
              image = "alpine"
              privileged = true
              poll_timeout = 360
              cpu_limit = "4"
              memory_limit = "8Gi"
              cpu_request = "2"
              memory_request = "4"
              [runners.kubernetes.node_selector]
                role = "worker"
                environment = "gitlab"
                size = "small"
            [runners.cache]
              Type = "azure"
              Path = "runner_cache"
              Shared = false
              [runners.cache.azure]
                AccountName = "${data.terraform_remote_state.dev.outputs.gl_runner_st_name}"
                AccountKey = "${data.terraform_remote_state.dev.outputs.gl_runner_st_key}"
                ContainerName = "${data.terraform_remote_state.dev.outputs.gl_runner_cache_container_name}"
                StorageDomain = "blob.core.windows.net"
        EOF
      }
      podSecurityContext = {
        runAsUser = 100
        fsGroup   = 65533
      }
      nodeSelector = {
        role        = "manager"
        environment = "gitlab"
      }
    })
  ]
}

