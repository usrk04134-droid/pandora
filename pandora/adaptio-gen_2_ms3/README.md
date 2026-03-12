# Adaptio

1. [Documentation](docs)
1. [Code documentation](src/DOCS.md)
1. [Requirements](docs/requirements.md)

## Quick start

Building the application: `nix build .#`
Running the application: `nix run .#`

### Development

The tools used to keep the code consistent are the following:

#### C++

clang-format, clang-tidy and editor config have configuration files present, to run clang-format on all source:

`clang-format -i src/**/*.cc src/**/*.h`

#### Python

Python is used for the system tests, please adhere to PEP 8.

### Building and running

Important: We have switched from ssh to https for git repo, which requires Gitlab Personal Access token to present in nix configuration. Ref to [Doc](https://esabgrnd.jira.com/wiki/spaces/ADTI/pages/237404161/Adaptio+Development+environment+in+non-NixOS+Linux+WSL#5.-Additional-Considerations)

```nix
access-tokens = gitlab.com=PAT:glpat-xxxxxxxxxxxxxx
```

To run the entire build chain, use `nix build .#`. This will build the default package.
It can also be built using cmake as usual.

To run the application you can either run the binary directly:

```bash
nix build .#

# followed by
./result/bin/adaptio
```

Or use nix run:

```bash
# with defaults
nix run .#

# or (with arguments)
nix run .# -- arguments
```

### Important: Update Core Library

Manually update the library's `rev` field in the flake.nix file.
Run the command below.

```bash
nix flake update
```

If the operation was successful the library's lastModified and narHash entries should be updated.

* adaptio-core-lib
* pndriver-lib

### Flake Input URL

Somehow flakes is not decoding gitlab url properly. There is an open issue [!9161](https://github.com/NixOS/nix/issues/9161).

To fix this, sub-group and repository is separated by `%2F` instead of `/`. Refer [this](https://github.com/NixOS/nix/issues/9161#issuecomment-1821857778)

### Running Tests

To run the tests, first build the test binaries:

```bash
nix build .#adaptio-tests
```

After building, execute the test binaries as follows:

```bash
./result/bin/adaptio-block-tests
./result/bin/adaptio-unit-tests
```

This will run both the block tests and unit tests for the project.

## Git Commit Message Format

Refer to [Git Commit Message Format documentation][git-commit-message-format]

## Semantic Versioning (SemVer)

Refer to [Semantic Versioning (SemVer) documentation][semver]

## Block Tests

Refer to [Block Tests documentation][block-tests]

## Lint Python

Refer to [Ruff: Python Linter and Formatter][lint-python]

## Lint Nix

Use `nixfmt` from this repository flake.

* **Check formatting (no changes):**

```bash
nix run .#nixfmt -- --check flake.nix
```

* **Check all `.nix` files in the repository (no changes):**

```bash
find . -type f -name '*.nix' -print0 | xargs -0 -r nix run .#nixfmt -- --check
```

* **Format files in place:**

```bash
find . -type f -name '*.nix' -print0 | xargs -0 -r nix run .#nixfmt --
```

[git-commit-message-format]: https://gitlab.com/esab/abw/infra-and-test#git-commit-message-format
[block-tests]: src/block_tests/BLOCK_TESTS.md
[lint-python]: https://gitlab.com/esab/abw/infra-and-test#ruff-introduction
[semver]: https://esabgrnd.jira.com/wiki/x/FwBNDw
