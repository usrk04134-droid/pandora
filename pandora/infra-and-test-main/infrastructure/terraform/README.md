# Terraform

> Docs: [Terraform Documentation](https://developer.hashicorp.com/terraform)

## Table of Contents

- [Terraform](#terraform)
   - [Table of Contents](#table-of-contents)
   - [How to set up remote backend](#how-to-set-up-remote-backend)
      - [Why not GitLab Backend](#why-not-gitlab-backend)
      - [Azure Backend](#azure-backend)
   - [Infrastructure Types](#infrastructure-types)
      - [Default](#default)
      - [Dev](#dev)
      - [Test](#test)
      - [Prod](#prod)
      - [GitLab](#gitlab)
   - [Services](#services)
      - [Nix cache (Nix StoreD)](#nix-cache-nix-stored)
         - [Setup](#setup)
         - [Deployment](#deployment)
         - [Files](#files)
   - [Ideal workflow](#ideal-workflow)
   - [Best Practices](#best-practices)
      - [For Terraform](#for-terraform)
      - [For Azure](#for-azure)

## How to set up remote backend

### Why not GitLab Backend

[GitLab Issue](https://gitlab.com/gitlab-org/gitlab/-/issues/233445)

No support for workspaces and management of multiple states files automatically.
We can achieve this behavior through env variables, symlinks and what not but...
Might as well use Azure.

### Azure Backend

[Hashicorp Documentation](https://developer.hashicorp.com/terraform/language/settings/backends/azurerm)

> **Note:**  
> As of azurerm provider v4.0, specifying the Azure Subscription ID is now **mandatory**.  
> You must set the `ARM_SUBSCRIPTION_ID` environment variable for all Terraform operations:
>
> ```sh
> export ARM_SUBSCRIPTION_ID="<your-subscription-id>"
> ```
>
> See: [azurerm 4.0 upgrade guide](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/guides/4.0-upgrade-guide#specifying-subscription-id-is-now-mandatory)

## Infrastructure Types

Currently there are 5 types of resources defined in our Terraform codebase.
These are directly related to Terraform workspaces.

1. `default`
1. `dev`
1. `test`
1. `prod`
1. `gitlab`

**Why do this and make it complex?**

**Blast radius:** This allows us to have multiple terraform state files. Which
means we reduce the risk of destroying all resources with a single command.

**Kubernetes, Helm and Azure Kubernetes Service (AKS):** There are no secrets,
certificates or any other info being saved when we create an AKS, we use
terraform interpolation to dynamically setup the Terraform Kubernetes and Helm
providers. However, if they are in the same state file, this will cause issues
if resources need to be deleted or re-created.

### Default

The `default` workspace will be used to spin up the basic infra necessary to
allow for the creation of a default resource group, default storage
(for terraform state files) and more. This is for base infrastructure that
should not be deleted and will not go through many changes. Resources deploying
in other workspaces will depend on some base resources created in this
workspace.

### Dev

This workspace will be used to spin up necessary infrastructure for developers'
needs, mainly CI related infrastructure for GitLab pipelines such as linting,
building, unit & sil testing etc. Infrastructure in this workspace can go
through changes depending on stability.

### Test

This workspace will be used for creating resources for all testing activities.
These can be system, integration or HIL testing. Or Infrastructure related to
logging/metrics etc etc.

### Prod

Ideally, all production related infrastructure is deployed on a new Azure
Subscription. It should also be deployed in completely isolated Terraform states.
So this needs to be planned out further.

### GitLab

For all GitLab related settings and infrastructure.

## Services

### Nix cache (Nix StoreD)

The `nix-stored` service acts as a Nix cache service for our build jobs running in our GitLab Runner, deployed in the same Kubernetes cluster.

#### Setup

- The `golang` service is bundled in a container image, see `container_files/nix-stored`. Which gets pushed to the projects private GitLab container registry.
- The image is defined in a local `helm` chart, see `helm/nix-stored`.
- The `helm` chart is configured and deployed by `terraform`, see below.
- The service is made accessible internally to GitLab via a ExternalName service, which translates between the internal `nix-cache` endpoint to its FQDN.

#### Deployment

- The service uses a `imagePullSecrets` consisting of a GitLab PAT in order to get access to GitLabs container registry to fetch the image.
- The pipelines uses a nix cache `Ed25519` secret key for signing store paths, this key is kept in the azure key vault and provided to each pipeline as a CI/CD variable.
- The pipelines also get the matching public key as a CI/CD variable (in order to trust prior jobs cached NARs).
- The signed store paths are automatically pushed to the nix cache via a `post-build-hook` provided as a file based CI/CD variable.
- The URL of the nix cache is also provided as a CI/CD variable.

#### Files

- **`gl_main.tf`**: Contains the CI/CD variable definitions.
- **`az_key_vault.tf`**: Contains the key definitions.
- **`helm_nix_cache.tf`**: Contains the service resource.

## Ideal workflow

Ideally, all infrastructure changes happen through CI (using GitLab shared
runners) using Azure Service Principals in the following steps.

> Note: There are some workflow examples and soon to be deprecated Terraform
> GitLab templates (due to BSL) that can be used for different stages.

1. Developer makes `.tf` related changes.
   1. _Optional_: Tests on local system using `terraform validate` & `terraform plan`
   1. Creates Merge Request to default branch
1. Other developers review changes.
1. Merge request pipelines are run:
   1. Lint-1: `terraform fmt -recursive` If files are modified, job fails, author updates MR.
   1. Lint-2: `terraform validate`
   1. Plan: `terraform plan -out <cool-plan>`
   1. **MANUAL** Deploy: `terraform apply -auto-approve`
1. Panic

> Note: `terraform validate` and `terraform plan` is only able to check what terraform knows, e.g. if you violate an API but comply with the provider all will seem ok. The issue only pops-up at `terraform apply` stage.

## Best Practices

Follow them. For more details on what is implemented, ask @Owais79 to document
his work. (It is currently 17:11 and I am lazy)

### For Terraform

[Best Practices](https://www.terraform-best-practices.com/)

### For Azure

[Resource Naming](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/azure-best-practices/resource-naming)
