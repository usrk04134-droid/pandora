# Nix StoreD

Nix StoreD (the D stands for Daemon) is a binary cache server for Nix,
designed to store and serve NAR files. It provides endpoints to upload,
download, and check the existence of NAR files. The server is built using
Go and leverages the oapi-codegen library for generating API code from
OpenAPI specifications. It includes basic authentication middleware to
secure endpoints and logging middleware for request tracing. The server
is configured via environment variables, making it flexible and easy to
deploy in various environments.

Refer to [Nix StoreD](https://github.com/ChrisOboe/nix-stored) for further project documentation and information.

## Table of Contents

- [Nix StoreD](#nix-stored)
   - [Table of Contents](#table-of-contents)
   - [Configuration](#configuration)
- [Setup](#setup)
   - [Installation](#installation)
   - [Nix Builder](#nix-builder)
   - [Nix Consumer](#nix-consumer)
   - [Additional Resources](#additional-resources)

## Configuration

The software can be configured using environment variables:

- `NIX_STORED_PATH`:             The path where NAR files are stored. Default
                                 is `/var/lib/nixStored`.
- `NIX_STORED_LISTEN_INTERFACE`: The interface and port on which the server
                                 listens. Default is `0.0.0.0:8100`.
- `NIX_STORED_USER_READ`:        The username for read access. Default is empty.
- `NIX_STORED_USER_READ_PASS`:   The password for read access. Default is empty.
- `NIX_STORED_USER_WRITE`:       The username for write access. Default is empty.
- `NIX_STORED_USER_WRITE_PASS`:  The password for write access. Default is empty.

Set these environment variables in your helm `values.yaml` environment to
customize the server's behavior. The store path from Nix Stored is completely independend from your Nix Store.

# Setup

## Installation

Deploy as you would any standard `helm` chart.

## Nix Builder

Now you want to get your system the builds stuff via nix to upload it to
nix-stored. You can configure this as
[post-build-hook](https://nix.dev/guides/recipes/post-build-hook.html)

## Nix Consumer

Just add your nix-stored as nix substituter. Just make sure the consumer knows the public key(s) of the builder(s).

## Additional Resources

- [Nix StoreD](https://github.com/ChrisOboe/nix-stored)
- [NixOS wiki on Binary Cache](https://nixos.wiki/wiki/Binary_Cache)
- [Nix.dev guide on post build hook](https://nix.dev/guides/recipes/post-build-hook.html)
- [Nix.dev manual on store types](https://nix.dev/manual/nix/latest/store/types/)
- [Nix.dev manual on substituters](https://nix.dev/manual/nix/latest/command-ref/conf-file.html#conf-substituters)
- [Nix.dev manual on trusted-public-keys](https://nix.dev/manual/nix/latest/command-ref/conf-file.html#conf-trusted-public-keys)
- [Nix.dev manual on secret-key-files](https://nix.dev/manual/nix/latest/command-ref/conf-file.html#conf-secret-key-files)
