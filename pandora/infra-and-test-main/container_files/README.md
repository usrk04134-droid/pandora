# Container Files

This directory contains container build configurations for various tools and environments used in CI/CD pipelines and development workflows. Container images can be built using either traditional Dockerfiles or Nix flakes, depending on the project requirements.

## Table of Contents

- [Container Files](#container-files)
   - [Table of Contents](#table-of-contents)
   - [Overview](#overview)
   - [Directory Structure](#directory-structure)
   - [Docker-Based Containers](#docker-based-containers)
      - [Building Docker Images](#building-docker-images)
      - [Running Docker Containers](#running-docker-containers)
   - [Nix Flake-Based Containers](#nix-flake-based-containers)
      - [What is Nix](#what-is-nix)
         - [Nix](#nix)
         - [Nix Command](#nix-command)
         - [Nix Flakes](#nix-flakes)
         - [Features](#features)
      - [Requirements](#requirements)
      - [Platform-Specific Setup](#platform-specific-setup)
         - [Darwin (MacOS)](#darwin-macos)
         - [Linux](#linux)
         - [Windows](#windows)
      - [Nix Flake Commands](#nix-flake-commands)
         - [See Available Targets](#see-available-targets)
         - [Building a Container Image](#building-a-container-image)
         - [Enter a Development Shell](#enter-a-development-shell)
         - [Run a Project](#run-a-project)
      - [Managing Dependencies](#managing-dependencies)
   - [CI Integration](#ci-integration)
      - [Docker-Based Container Builds](#docker-based-container-builds)
      - [Nix Flake-Based Container Builds](#nix-flake-based-container-builds)
   - [Adding New Containers](#adding-new-containers)
      - [Adding a Docker-Based Container](#adding-a-docker-based-container)
      - [Adding a Nix Flake-Based Container](#adding-a-nix-flake-based-container)
   - [Additional Resources](#additional-resources)

## Overview

This directory provides container images for:

- **CI/CD tools**: linters, formatters, test runners
- **Build environments**: language-specific toolchains and build tools
- **Development environments**: reproducible development shells

Each subdirectory contains the configuration for building a specific container image, using either:

1. **Dockerfile**: Traditional Docker-based builds (most containers)
2. **flake.nix**: Nix flake-based builds with enhanced reproducibility (nix-stored, test-env)

## Directory Structure

```bash
container_files/
├── adaptio_ci/          # CI environment with Nix tooling (Dockerfile)
├── eslint/              # ESLint and Stylelint tools (Dockerfile)
├── gitlint/             # Git commit message linting (Dockerfile)
├── laserbeak/           # Deployment tool for system tests (Dockerfile)
├── manifest_validator/  # Manifest validation tool (Dockerfile)
├── markdownlint/        # Markdown linting (Dockerfile)
├── markdownlint_cli2/   # Markdown linting CLI v2 (Dockerfile)
├── nix-stored/          # Nix artifact storage tool (Nix flake)
│   └── flake.nix
├── podman/              # Podman-in-Docker (Dockerfile)
├── pytest/              # Python testing framework (Dockerfile)
├── ruff/                # Python linter and formatter (Dockerfile)
├── shellcheck/          # Shell script linting (Dockerfile)
├── snitch/              # Test result monitoring tool (Dockerfile)
├── tagger/              # Git tagging automation tool (Dockerfile)
├── test-env/            # Python test environment with Playwright (Nix flake)
│   └── flake.nix
└── README.md            # This file
```

## Docker-Based Containers

Most containers in this directory use traditional Dockerfiles. Each subdirectory contains a `Dockerfile` that defines the container image build process.

### Building Docker Images

Navigate to the desired container directory and build using Docker or Podman:

```bash
cd eslint
docker build -t eslint:local .

# Or using Podman
podman build -t eslint:local .
```

### Running Docker Containers

Run the container with appropriate volume mounts and commands:

```bash
# Example: Running ESLint
docker run --rm -v $(pwd):/workspace eslint:local eslint /workspace

# Example: Running pytest
docker run --rm -v $(pwd):/workspace pytest:local pytest /workspace/tests
```

Refer to individual project documentation or CI pipeline configurations for specific usage patterns.

## Nix Flake-Based Containers

Some containers (`nix-stored`, `test-env`) use Nix flakes for enhanced reproducibility and declarative configuration. Nix flakes provide deterministic builds with version-locked dependencies.

**Available Nix flake containers:**

- **nix-stored**: Container wrapping the nix-stored tool for managing and storing Nix build artifacts
- **test-env**: Python test environment with pytest, Playwright, and system test tools (testzilla, laserbeak, snitch)

### What is Nix

#### Nix

**Nix** is a powerful package manager that ensures reproducibility and isolation of software environments by treating packages as purely functional, avoiding side-effects.

#### Nix Command

**Nix command** is the modern unified interface for managing Nix packages and environments (`nix-command` in docs, `nix <subcmd>` in CLI). It replaces older commands like `nix-env` and `nix-build`, providing consistent syntax for package installation, building, running, and interacting with flakes.

#### Nix Flakes

**Nix Flakes** is a feature that simplifies dependency management and reproducibility by adding structured metadata and version locking to Nix projects. Each flake includes:

- **flake.nix**: Defines the project configuration, dependencies, and outputs
- **flake.lock**: Locks dependency versions to specific commits for reproducible builds

> Note: We do not support legacy `default.nix` workflows; all developers are expected to use Nix Flakes.

#### Features

- **Declarative Configuration**: Define projects and dependencies using Nix expressions
- **Reproducibility**: Deterministic builds ensuring consistency across environments
- **Nix Store Optimization**: Only includes necessary dependencies, resulting in lightweight containers

### Requirements

For working with Nix flake-based containers, install:

- [Nix package manager](https://nixos.org/download.html)
- Enable experimental features by adding to `/etc/nix/nix.conf` or `~/.config/nix/nix.conf`:

```properties
experimental-features = nix-command flakes
```

### Platform-Specific Setup

#### Darwin (MacOS)

Most Nix flakes target `x86_64-linux`. For macOS development, use Podman with Rosetta II:

**Install prerequisites:**

```bash
# Install Nix (using Determinate Nix Installer recommended)
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install

# Install Podman
brew install podman
```

**Create Podman machine with Rosetta II support:**

```bash
# Create VM with memory allocation
podman machine init --memory 12288

# Start the VM
podman machine start
```

**Create nix.conf for containers:**

```properties
experimental-features = nix-command flakes
filter-syscalls = false
sandbox = relaxed
```

**Run x86_64-linux containers on macOS:**

```bash
# Authenticate to GitLab container registry
echo "$TOKEN" | podman login registry.gitlab.com --username <username> --password-stdin

# Create development container
podman create --name dev --interactive --tty --arch amd64 \
    --volume $(pwd)/nix.conf:/etc/nix/nix.conf \
    --volume ~/.ssh:/root/.ssh:ro \
    --volume $(pwd):/workspace \
    registry.gitlab.com/esab/abw/infra-and-test/adaptio-ci:<tag>

# Start and attach to container
podman start --interactive --attach dev
```

This setup provides an x86_64-linux environment on macOS for building and testing Nix flake containers. Use `Ctrl-P` + `Ctrl-Q` to detach from the container while keeping it running.

#### Linux

```bash
# Install Nix via your package manager
# Debian/Ubuntu
curl -L https://nixos.org/nix/install | sh

# Configure nix.conf
echo "experimental-features = nix-command flakes" >> ~/.config/nix/nix.conf
```

For specific projects, you may need additional settings:

```properties
allow-import-from-derivation = true
sandbox = relaxed
```

#### Windows

Use WSL2 (Windows Subsystem for Linux) and follow the Linux setup instructions. Nix works well in WSL2 environments.

### Nix Flake Commands

#### See Available Targets

```bash
cd nix-stored
nix flake show
```

This displays all outputs defined in the `flake.nix` file.

#### Building a Container Image

Each flake contains a `containerImage` output used by CI:

```bash
cd nix-stored
nix build .#containerImage
```

The built image will be available as `result` in the current directory.

#### Enter a Development Shell

Access a development environment with all dependencies:

```bash
cd test-env
nix develop
```

This loads the environment defined by the flake's `devShell` output.

#### Run a Project

If the flake defines an `apps` output:

```bash
cd test-env
nix run
```

### Managing Dependencies

Dependencies for Nix flake projects are defined in the `inputs` section of `flake.nix`. The `flake.lock` file ensures reproducible builds by pinning exact versions.

To update dependencies:

```bash
nix flake update
```

## CI Integration

Container images in this directory are automatically built and pushed to the GitLab container registry by CI/CD pipelines.

### Docker-Based Container Builds

Docker containers are built using the `.gitlab-ci/build-and-push-image.yml` template. The CI pipeline:

- Triggers on changes to Dockerfiles
- Builds images using Podman
- Tags with version from `LABEL version` in Dockerfile
- Pushes to `registry.gitlab.com/esab/abw/infra-and-test/<container-name>`

### Nix Flake-Based Container Builds

Nix flake containers are built using the `.gitlab-ci/build-and-push-flake.yml` template. The CI pipeline:

- Triggers on changes to `flake.nix` or `flake.lock`
- Builds the `containerImage` output defined in each flake
- Extracts version tag from the flake configuration
- Pushes to the container registry

**Requirements for CI integration:**

- Each Nix flake MUST export a `packages.containerImage` output
- The container image should have a `tag` field for versioning
- Update `.gitlab-ci.yml` to include the new container in the build matrix

Example CI matrix entry:

```yaml
- IMG_NAME: 'test-env'
  IMG_FILES: 'container_files/test-env'
```

## Adding New Containers

### Adding a Docker-Based Container

1. Create a new subdirectory:

   ```bash
   mkdir new-tool
   cd new-tool
   ```

2. Create a `Dockerfile` with your container configuration:

   ```dockerfile
   FROM alpine:latest

   LABEL version="0.1.0"

   RUN apk add --no-cache your-tool
   ```

3. Build and test:

   ```bash
   docker build -t new-tool:test .
   docker run --rm new-tool:test your-tool --version
   ```

4. Update CI pipelines to build and push the image.

### Adding a Nix Flake-Based Container

1. Create a new subdirectory:

   ```bash
   mkdir new-flake-project
   cd new-flake-project
   ```

2. Create a `flake.nix` file. Use existing flakes as templates:

   ```bash
   # Simple example: copy from nix-stored
   cp ../nix-stored/flake.nix .

   # Complex example: copy from test-env
   cp ../test-env/flake.nix .
   ```

3. Edit `flake.nix` to define:
   - Project description and inputs
   - A `containerImage` output (required for CI integration)
   - Optional `devShells` for development environments
   - Optional `apps` for runnable applications

4. Create the lock file:

   ```bash
   nix flake lock
   ```

5. Test the flake:

   ```bash
   nix build .#containerImage
   nix develop  # If devShell is defined
   ```

6. Update CI configuration in `.gitlab-ci.yml` to include your new container in the build matrix.

7. Commit both `flake.nix` and `flake.lock` to the repository.

## Additional Resources

**General:**

- [Docker Documentation](https://docs.docker.com/)
- [Podman Documentation](https://docs.podman.io/)

**Nix:**

- [Nix Package Manager](https://nixos.org/download.html)
- [Zero to Nix](https://zero-to-nix.com/)
- [NixOS Wiki - Flakes](https://nixos.wiki/wiki/Flakes)
- [The Determinate Nix CLI Installer](https://github.com/DeterminateSystems/nix-installer)
- [Setting up Nix on macOS](https://nixcademy.com/posts/nix-on-macos/)
- [Podman 5.0 Release](https://blog.podman.io/2024/03/podman-5-0-has-been-released/)
