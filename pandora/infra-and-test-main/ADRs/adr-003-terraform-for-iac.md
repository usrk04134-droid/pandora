# ADR 003: Terraform used for IaC (Infrastructure as Code)

## Status

Accepted

## Context

Managing infrastructure manually is error-prone and does not scale well. The Godzilla DevOps team needs a consistent and reproducible way to define and manage infrastructure for CI/CD systems, cloud-based resources (e.g., Az, AKS, K8 clusters, VMs, Storage) and local test resource (e.g., HIL).

## Decision

Terraform SHALL be used as the Infrastructure as Code (IaC) tool for managing both cloud infrastructure (Azure, GitLab, K8s) and local test environments (HIL). It provides a declarative way to define infrastructure resources, supports multiple cloud providers, and allows us to version control infrastructure configurations.

## Consequences

### Positive

- Version-controlled and auditable infrastructure changes.
- Declarative and scalable infrastructure management for both HIL and cloud.
- Integration with the existing CI/CD pipelines, enabling automated infrastructure provisioning.

### Negative

- Initial setup and module creation can take time.
- Steep learning curve for team members new to Terraform.
- Potential drift between actual infrastructure state and the declared state in large environments without regular monitoring.

## References

- [What is Terraform?](https://developer.hashicorp.com/terraform/intro)
- [Azure provider](https://registry.terraform.io/providers/hashicorp/azurerm/latest)
- [GitLab provider](https://registry.terraform.io/providers/gitlabhq/gitlab/latest)
- [Kubernetes provider](https://registry.terraform.io/providers/hashicorp/kubernetes/latest)
- [Helm provider](https://registry.terraform.io/providers/hashicorp/helm/latest)
