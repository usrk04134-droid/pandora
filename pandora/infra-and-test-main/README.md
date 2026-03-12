# Infra and Test

## Description

Welcome to the wonderful world of infrastructure and test :-)

## Table of Contents

- [Infra and Test](#infra-and-test)
   - [Description](#description)
   - [Table of Contents](#table-of-contents)
   - [Repository Structure](#repository-structure)
   - [Managed Tokens](#managed-tokens)
   - [Git Commit Message Format](#git-commit-message-format)
      - [Configuration](#configuration)
      - [Lint Commits](#lint-commits)
      - [Pre-commit Hooks](#pre-commit-hooks)
   - [SOPS: Secrets OPerationS](#sops-secrets-operations)
      - [Introduction](#introduction)
      - [Installation](#installation)
      - [Editing secrets](#editing-secrets)
      - [Adding encryption keys](#adding-encryption-keys)
   - [Ruff: Python Linter and Formatter](#ruff-python-linter-and-formatter)
      - [Ruff Introduction](#ruff-introduction)
      - [Ruff Installation](#ruff-installation)
      - [Ruff Linter](#ruff-linter)
      - [Ruff Formatter](#ruff-formatter)

## Repository Structure

Pipeline templates and scripts are located in [.gitlab-ci](.gitlab-ci).

Dockerfiles and other container related resources are located in [container_files](container_files).

Diagrams is located in [diagrams](diagrams).

Nix flakes and documentation is located in [flakes](flakes).

Helm charts and documentation is located in [infrastructure/helm](infrastructure/helm).

Terraform configurations and documentation is located in [infrastructure/terraform](infrastructure/terraform).

## Managed Tokens

The table below lists secrets we use in our infrastructure that requires manual rotation. \
The token values are stored in our Azure KeyVault and added to GitLab variables through the use of Terraform.

> [!important]
> When a variable needs to be updated with a new value, i.e., a token has been updated in the KeyVault,\
> Terraform must be run to update the variable with the new value.

| GitLab variable                |  Description                                                        | Expiration |
|--------------------------------|---------------------------------------------------------------------|------------|
| `NIX_CONFIG`                   | Token (`flake_repo_token`) used by flake inputs in gitlab pipelines | 2025-10-03 |
| `PLC_APAX_TOKEN`               | PLC development token for use with Apax tools.<br>The token is renewed by @simonkampe. | 2025-11-13 |
| `SERVICE_ACCOUNT_PAT`          | PAT of our service account bot (Mechagodzilla)                      | 2025-10-03 |
| `TESTZILLA_TESTRAIL_API_KEY`   | Testrail API Key. The key belongs to the Testzilla user on Testrail.<br>For Testzilla user credentials check with @karthipalani. |            |

## Git Commit Message Format

[Adaptio wiki - Git commit message format](https://gitlab.com/groups/esab/abw/-/wikis/Infrastructure-&-Test/Git-commit-message-format)

### Configuration

The `.gitmessage` file in this project can be used as a git message template for all projects

```bash
git config --global commit.template /path/to/.gitmessage
```

Using nix, run

```bash
#Set template locally
nix run .#gittemplate

#Set template globally
nix run .#gittemplate -- --global

#Remove local template
nix run .#gittemplate -- --uninstall

#Remove global template
nix run .#gittemplate -- --global --uninstall
```

### Lint Commits

Now, you can lint your commit messages locally before push your commits, run

```bash
nix run .#gitlint

# Lint specific commit
nix run .#gitlint -- --commit "COMMIT_SHA"
```

For Advanced users, for more ```--commit```  options refer [here](https://jorisroovers.com/gitlint/latest/linting_specific_commits/).

### Pre-commit Hooks

You can also have pre-commit hooks in your local repo, to validate your commit messages automatically during commit.

The pre-commit hooks currently configured:

**Code Quality & Formatting:**

- **gitlintHook**: Validates commit messages
- **end-of-file-fixer**: Ensures files end with a newline
- **nixfmt-rfc-style**: Formats Nix files according to RFC style
- **terraform-format**: Formats Terraform files
- **hadolint**: Lints Dockerfiles for best practices
- **helmTemplateHook**: Validates and lints Helm charts

**Security:**

- **check-added-large-files**: Prevents committing large files/binaries (>500KB)

#### Usage

```bash
# Install pre-commit hooks
nix run .#pre-commit -- install

# Run hooks manually on all files (without committing)
nix run .#pre-commit -- run --all-files

# Run hooks on staged files only
nix run .#pre-commit -- run

# Run a specific hook by ID
# Available IDs: check-added-large-files, end-of-file-fixer, gitlintHook, 
#                hadolint, helmTemplateHook, nixfmt-rfc-style, terraform-format
nix run .#pre-commit -- run helmTemplateHook

# Update pre-commit hooks
nix run .#pre-commit -- --update

# Uninstall pre-commit hooks
nix run .#pre-commit -- --uninstall
```

> [!note]
> pre-commit will create `.pre-commit-config.yaml` specific to local repo. It fails, if a config created by developer already exists.

## Nix Formatter

### Nix Formatter Introduction

We use [nixfmt-rfc-style](https://github.com/NixOS/nixfmt) to format all Nix files according to RFC style guidelines. This ensures consistent formatting across the repository.

### Running Nix Formatter

Check if Nix files conform to RFC style formatting without modifying them (dry-run):

```bash
# Check all .nix files in the repository
nix run .#nixfmt -- --check $(find . -name '*.nix' -type f)

# Check a specific file
nix run .#nixfmt -- --check path/to/file.nix

# Check all .nix files in a directory
nix run .#nixfmt -- --check $(find path/to/directory -name '*.nix' -type f)
```

### Applying Nix Formatter

Format Nix files according to RFC style:

```bash
# Format all .nix files in the repository
nix run .#nixfmt -- $(find . -name '*.nix' -type f)

# Format a specific file
nix run .#nixfmt -- path/to/file.nix

# Format all .nix files in a directory
nix run .#nixfmt -- $(find path/to/directory -name '*.nix' -type f)
```

## SOPS: Secrets OPerationS

### Introduction

[SOPS](https://getsops.io/) is what we use to store secrets in Git.

[.sops.yaml](.sops.yaml) is the configuration file for SOPS. In this file we specify how our secrets shall be encrypted and decrypted.

[secrects.yaml](secrets.yaml) is the file that contains the secrets. When stored in Git, it is encrypted according to the configuration in `.sops.yaml`.

To be able to decrypt the `secrets.yaml` file for writing or reading secrets `sops` needs to be installed on your system.

### Installation

> [!important]
> Due to a problem with newer versions of `sops` and Azure KeyVault, it is important to not install a version later than `3.7.3`

```bash
# Download the binary
curl -LO https://github.com/getsops/sops/releases/download/v3.7.3/sops-v3.7.3.linux.amd64

# Move the binary in to your PATH
sudo mv sops-v3.7.3.linux.amd64 /usr/local/bin/sops

# Make the binary executable
sudo chmod +x /usr/local/bin/sops
```

### Editing secrets

Once `sops` is installed you can use it to access the secrets.yaml file.

To be able to decrypt and edit the `secrets.yaml` file you must have access to at least one of the keys that was used to encrypt the file.\
If you are not a HIL-PC with access to the applicable AGE keys, the only other option is a key stored in our `AzureKV`.

For `sops` to be able to access `Azure` and the KeyVault, you might first have to do `az login`.

If you have access to decrypt the file, the `sops` command will open it in your default editor.

```bash
sops secrets.yaml
```

If the file has been changed, `sops` will encrypt it again when you close it.

### Adding encryption keys

In the `.sops.yaml` configuration file we specify all the keys that shall be used to encrypt the `secrets.yaml` file.

If a new key is added, the `secrets.yaml` must also be re-encrypted with the new key.

This is done by issueing the following command:

```bash
sops updatekeys secrets.yaml
```

## Ruff: Python Linter and Formatter

The pipeline job template for Python linting: [lint-python.yml](.gitlab-ci/lint-python.yml) \
The default configuration file used by the linting job: [ruff.toml](container_files/ruff/ruff.toml)

### Ruff Introduction

An extremely fast Python linter and code formatter, written in Rust.

### Ruff Installation

Install Ruff via pip,

```bash
pip install ruff==0.11.5
```

### Ruff Linter

`ruff check` is the primary entrypoint to the Ruff linter. It accepts a list of files or directories, and lints all discovered Python files, optionally fixing any fixable errors. When linting a directory, Ruff searches for Python files recursively in that directory and all its subdirectories.

```bash
ruff check                  # Lint files in the current directory.
ruff check --fix            # Lint files in the current directory and fix any fixable errors.
ruff check --watch          # Lint files in the current directory and re-lint on change.
ruff check path/to/code/    # Lint files in `path/to/code`.
```

### Ruff Formatter

`ruff format` is the primary entrypoint to the formatter. It accepts a list of files or directories, and formats all discovered Python files.

```bash
ruff format                   # Format all files in the current directory.
ruff format path/to/code/     # Format all files in `path/to/code` (and any subdirectories).
ruff format path/to/file.py   # Format a single file.
```
