# ADR 005: Azure and AKS (Azure Kubernetes Service)

## Status

Accepted

## Context

The Godzilla DevOps team requires a reliable cloud provider to host CI/CD infrastructure, support Kubernetes orchestration, and provide integration with our existing services. The selected solution should provide scalability, security, and ease of integration.

## Decision

Azure SHALL be used as the cloud provider, and Azure Kubernetes Service (AKS) SHALL be used for managing the Kubernetes clusters. Azure provides strong integration with enterprise services and a robust AKS offering that simplifies Kubernetes management with built-in monitoring, security, and scalability.

## Consequences

### Positive

- Tight integration with Azure services like Azure Entra ID (formerly Azure Active Directory), Azure Storage, Azure Key Vault, and Azure DevOps.
- Managed Kubernetes service reduces operational overhead for cluster management.
- Strong security, compliance, and enterprise features.
- Provides simple integration with Entra ID, which is the identity and access management solution used by the company.
- Is the current cloud provider for the company, for which billing and subscription policies are defined by the IT department, and thus cloud provider of choice.
- Have good Command-Line Interface (CLI) tooling for managing the infrastructure.

### Negative

- Cost associated with Azure services can increase as infrastructure scales.
- Limited portability compared to a multi-cloud or on-premises Kubernetes solution.
- Does not provide a S3 compatible storage API.
- Potential vendor lock-in due to reliance on Azure-specific features.

## References

- [Microsoft Azure](https://azure.microsoft.com/en-us)
- [Azure Kubernetes Service](https://learn.microsoft.com/en-us/azure/aks/what-is-aks)
- [Azure CLI](https://learn.microsoft.com/en-us/cli/azure/)
- [Microsoft Entra ID](https://www.microsoft.com/en-us/security/business/identity-access/microsoft-entra-id)
- [Azure Key Vault](https://azure.microsoft.com/en-us/products/key-vault)
- [Azure Blob Storage](https://azure.microsoft.com/en-us/products/storage/blobs)
