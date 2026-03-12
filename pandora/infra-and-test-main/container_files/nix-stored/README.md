# Nix Flake for Building Nix StoreD

This directory contains a Nix Flake that builds a container image for `Nix StoreD` using the Nix package manager, leveraging the declarative and reproducible nature of Nix.

## Table of Contents

- [Nix Flake for Building Nix StoreD](#nix-flake-for-building-nix-stored)
   - [Table of Contents](#table-of-contents)
- [Usage](#usage)
   - [Structure](#structure)
   - [Additional Resources](#additional-resources)

# Usage

1. **Clone the repository**:

   ```bash
   git clone <repository-url>
   cd <repository-directory>
   ```

1. **Build the container image** using Nix:

   ```bash
   nix build .#containerImage
   ```

   This command builds the container image defined in the `containerImage` output in `flake.nix`.

1. **Load the image into Podman**:

   ```bash
   podman image load --input result
   ```

1. **Tag the image**:

   ```bash
   podman image tag <image ID> <new-name:version>
   ```

   The `<image ID>` placeholder is for image ID as printed when loading the image into podman.

1. **Run the container**:

   ```bash
   podman run --interactive --tty --rm <image-name:version>
   ```

## Structure

- `flake.nix`: The Nix Flake that defines the container image, dependencies, and build process.
- `default.nix`: The Nix expression that configures the contents of the container image.

## Additional Resources

- [Nix StoreD](https://github.com/ChrisOboe/nix-stored)
