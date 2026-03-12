# Building and Running Tests Outside a Nix Develop Shell

## Background

The `adaptio.sh` script is the primary developer entry point for building and
running Adaptio and its tests. Its `--build-tests` command calls `cmake`
directly, which means it only works inside a `nix develop` shell where the full
toolchain (`cmake`, `clang`, etc.) is on `PATH`. This makes it inconvenient to
invoke from contexts where entering a `nix develop` shell first is undesirable
or impractical — for example, from editor integrations, external scripts, or
CI-adjacent tooling that already handles the environment differently.

`nix build .#adaptio-tests` is fully self-contained: it resolves its own
toolchain from the flake and does not require a `nix develop` shell.

---

## Solution: `nix-test.sh`

A dedicated script `nix-test.sh` handles building and running tests via
`nix build`, leaving `adaptio.sh` unchanged. `adaptio.sh` remains the
cmake-based entry point for use inside `nix develop`.

```bash
bash nix-test.sh -b   # build tests
bash nix-test.sh -u   # run unit tests (builds first if needed)
bash nix-test.sh -k   # run block tests (builds first if needed)
bash nix-test.sh -q   # run quick block tests (builds first if needed)
```

No `nix develop` shell required for any of these commands.

For incremental development inside `nix develop`, continue using `adaptio.sh`
as before:

```bash
nix develop
bash adaptio.sh -t          # build tests (incremental cmake)
bash adaptio.sh --unit-tests
bash adaptio.sh --quick-block-tests
```

---

## Output Path: `result-tests/` vs `build/debug/`

The cmake build writes binaries to `build/debug/src/`. `nix-test.sh` uses a
named output link:

```bash
nix build .#adaptio-tests --out-link result-tests
```

This keeps the symlink `result-tests/` stable regardless of other `nix build`
invocations (e.g. `nix build .#adaptio-debug` would overwrite a bare `result`
symlink, but leaves `result-tests` untouched).

The Nix store is read-only, but this is not a problem in practice since test
runners write logs elsewhere.

---

## Build Time and Caching

This is the most significant trade-off between the two approaches.

### Inside `nix develop` with cmake

cmake performs **incremental compilation**: only translation units that have
changed (or whose headers have changed) are recompiled. A one-line change to a
single `.cc` file typically takes a few seconds to rebuild and re-link.

### `nix build` with a dirty input

`nix build` computes a hash over all inputs to the derivation — all source
files, the `flake.nix`, and transitive flake inputs. If any input differs from
a previously cached derivation, nix builds from scratch in a fresh sandbox.
**There is no incremental compilation between `nix build` invocations.** Every
source change triggers a full clean build.

| Scenario | cmake (nix develop) | nix build |
|---|---|---|
| First build | Slow (full build) | Slow (full build) |
| One file changed | Fast (incremental) | Slow (full rebuild) |
| No files changed | Instant | Instant (cache hit) |
| After `git clean` | Slow (full build) | Instant (cache hit, store unchanged) |
| Different machine, same inputs | Slow (no shared cache) | Fast (binary cache hit, if configured) |

The cache hit case for `nix build` is genuinely instant — if the input hash
matches a derivation already in the local store or a configured binary cache,
no compilation happens at all. This is an advantage when switching between
branches where the test code hasn't changed.

The incremental advantage of cmake is decisive during active development with
frequent small changes.
