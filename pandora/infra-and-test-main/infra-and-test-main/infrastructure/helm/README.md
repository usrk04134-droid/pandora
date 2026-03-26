# Helm Charts Directory

This directory contains custom Helm charts used to deploy various services and applications in our AKS Kubernetes cluster. Each subdirectory in this folder SHALL represent an individual Helm chart. Each chart is intended to be modular and customizable to suit different environments and use cases.

## Table of Contents

- [Helm Charts Directory](#helm-charts-directory)
   - [Table of Contents](#table-of-contents)
   - [What is Helm](#what-is-helm)
   - [Directory Structure](#directory-structure)
   - [Requirements](#requirements)
- [Usage](#usage)
   - [Customizing Values](#customizing-values)
- [Additional Resources](#additional-resources)

## What is Helm

[Helm](https://helm.sh/) is a package manager for Kubernetes, allowing you to define, install, and upgrade even the most complex Kubernetes applications. It helps manage Kubernetes manifests using Charts, which are collections of files that describe a related set of Kubernetes resources.

With Helm, you can:

- Easily deploy applications to a Kubernetes cluster.
- Manage the versioning and upgrading of those applications.
- Simplify the process of sharing applications within teams.

## Directory Structure

Each subdirectory contains a separate Helm chart. The typical structure of a Helm chart is as follows:

```bash
chart-name/
├── charts/                 # Subcharts for dependencies
│  └── ...                  #
├── templates/              # Kubernetes resource templates
│  ├── _helpers.tpl         # Reusable template functions
│  ├── deployment.yaml      # Deployment resource for pods
│  ├── ingress.yaml         # Ingress config for external access
│  ├── service.yaml         # Application Service config
│  ├── configmap.yaml       # Stores non-sensitive config in ConfigMap
│  ├── secret.yaml          # Stores sensitive data in Secret
│  ├── serviceaccount.yaml  # ServiceAccount definitions for pod permissions
│  ├── hpa.yaml             # Horizontal Pod Autoscaler config
│  ├── pvc.yaml             # Storage requests via PersistentVolumeClaim
│  └── ...                  # Other resource types
├── .helmignore             # File exclude patterns
├── Chart.yaml              # Chart metadata
├── NOTES.txt               # Optional Post-deployment instructions
├── README.md               # Optional readme for the chart
└── values.yaml             # Default values for the chart
```

- **`charts/`**: Contains any dependencies that the chart requires.
- **`templates/`**: Contains YAML templates for Kubernetes resources (such as Deployments, Services, ConfigMaps, etc.).
- **`Chart.yaml`**: The file that contains metadata about the chart (name, version, description, etc.).
- **`values.yaml`**: A file with default values that can be customized when deploying the chart.

## Requirements

To use any of the charts in this directory, first ensure you have Helm installed. You can install Helm by following the instructions in the official [Helm documentation](https://helm.sh/docs/intro/install/).

# Usage

Once Helm is installed, you can lint and locally render the chart template:

```bash
# Navigate to the directory containing the chart
cd <chart-directory>

# Lint the chart
helm lint

# Locally render the template
helm template <instance name> .
```

> NOTE: We do not install nor upgrade the charts using `helm`, we use `terraform` for that!

## Customizing Values

Each Helm chart provides a `values.yaml` file where default configuration values are specified. We override these values in our `terraform` configuration.

# Additional Resources

- [Helm Documentation](https://helm.sh/docs/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Helm Chart Best Practices](https://helm.sh/docs/chart_best_practices/)
