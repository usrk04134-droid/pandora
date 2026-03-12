# ADR 006: GitLab pipelines and Kubernetes-based runner in AKS for CI/CD

## Status

Proposed

## Context

To have an efficient and easily automated build, test, and deployment process, we need a CI/CD pipeline integrated with GitLab. The pipelines must be scalable, efficient, and capable of running on cloud infrastructure to handle varying workloads.

## Decision

GitLab CI/CD pipelines SHALL be used for automating the build and test processes. Kubernetes-based GitLab runners SHALL be deployed in Azure Kubernetes Service (AKS) to handle the scaling needs of the CI/CD jobs along with local deployment of GitLab runners in the HIL rigs.

## Consequences

### Positive

- Scalable runners in AKS ensure efficient resource allocation based on job load.
- Seamless integration with GitLab provides a single platform for code and CI/CD management.
- Possibility of K8s managed shared scalable cache solution.
- High availability and fault tolerance due to the use of cloud resources.

### Negative

- Cost associated with running Kubernetes clusters in Azure.
- Monitoring and maintaining the runner infrastructure can require additional effort.
- Potential latency for jobs if not optimized for AKS.

## References

- [Get started with GitLab CI/CD](https://docs.gitlab.com/ee/ci/)
- [GitLab Kubernetes runner](https://docs.gitlab.com/runner/executors/kubernetes/)
