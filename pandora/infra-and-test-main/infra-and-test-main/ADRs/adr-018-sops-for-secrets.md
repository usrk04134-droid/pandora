# ADR 018: Using SOPS as Secret Management System in Infrastructure Settings

## Status

Proposed

## Context

Managing secrets such as API keys, credentials, and sensitive configurations is critical in modern infrastructure. Storing these secrets in Git provides version control but requires robust encryption. SOPS (Secrets OPerationS) provides a secure, user-friendly, and auditable way to manage secrets, especially when integrated with Azure Key Vault (Azure KV) and sops-nix for Nix-based deployments.

Azure KV will store the master encryption key, and deployment-specific AGE keys will be used for isolated decryption capabilities. sops-nix will streamline the management of secrets in NixOS configurations, ensuring declarative and automated workflows.

## Decision

We SHALL use SOPS for encrypting secrets stored in Git repositories, leveraging different support tools for seamless integrations in our environment. SOPS SHALL be used for secure encryption and decryption of secrets in YAML, JSON, and other formats. Azure Key Vault SHALL be used for managment of the master key, used by developers interacting with the repository. AGE keys SHALL be used for deployment-specific (e.g. HIL, Demo and other test rigs) encryption & decryption of the secrets, providing environment isolation and least-privilege access. Sops-nix SHALL be used for declarative secret integration with NixOS (e.g. HIL).

## Consequences

### Positive

- Enhanced security through strong encryption and environment-specific keys reduce risks.
- Version control of encrypted secrets ensure secrets are securely stored in Git.
- Seamless integration with Nix-based deployments using sops-nix.
- Auditability of master key used via Azure KV logs and tracking of key usage.

### Negative

- Learning curve of team members; need to learn SOPS, Azure KV, AGE, and sops-nix.
- Key Management Complexity: Requires careful management of multiple keys.

## References

- [SOPS Repo](https://github.com/getsops/sops)
- [SOPS: Simple And Flexible Tool For Managing Secrets](https://getsops.io/)
- [Azure Key Vault](https://azure.microsoft.com/en-us/services/key-vault/)
- [AGE Encryption](https://age-encryption.org/)
- [sops-nix](https://github.com/Mic92/sops-nix)
