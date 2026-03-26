#!/usr/bin/env bash

# Builds and runs Adaptio tests, choosing the fastest available method:
#
#   - Incremental (fast): when started from within a `nix develop` shell,
#     cmake is in PATH and ninja only recompiles changed files.
#     Binaries are written to build/debug/src/.
#
#   - Full Nix build (slow, unless nix cache hit): fallback when cmake is not in PATH.
#     Delegates to nix-test.sh. Binaries are written to result-tests/bin/.
#
# Same interface as nix-test.sh. Must be run from the adaptio/ root directory.

if [ ! -e dev-test.sh ]
then
  echo "Script must be run in root project directory (adaptio/)."
  exit 1
fi

COMMAND=""
PASS_ARGS=()

usage() {
  echo "Usage: $(basename "$0") [OPTIONS] [-- <test runner args>]"
  echo "Options:"
  echo "  -h, --help              Display this help message"
  echo "  -b, --build             Build test binaries"
  echo "  -u, --unit-tests        Run unit tests (builds first if needed)"
  echo "  -k, --block-tests       Run block tests (builds first if needed)"
  echo "  -q, --quick-block-tests Run block tests excluding slow suite (builds first if needed)"
}

if [ $# -eq 0 ]
then
  usage
  exit 1
fi

while [ $# -gt 0 ]
do
  case "$1" in
    -h | --help )              usage; exit 0 ;;
    -b | --build )             COMMAND="build" ;;
    -u | --unit-tests )        COMMAND="unit-tests" ;;
    -k | --block-tests )       COMMAND="block-tests" ;;
    -q | --quick-block-tests ) COMMAND="quick-block-tests" ;;
    -- ) shift; PASS_ARGS=("$@"); break ;;
    * ) echo "Unknown argument: $1"; echo ""; usage; exit 1 ;;
  esac
  shift
done

if command -v cmake > /dev/null 2>&1
then
  # Incremental build via cmake/ninja (nix develop environment)
  echo "[dev-test] Using incremental cmake build (nix develop)"
  UNIT_BIN="./build/debug/src/adaptio-unit-tests"
  BLOCK_BIN="./build/debug/src/adaptio-block-tests"

  ensure_built() {
    if [ ! -e "$UNIT_BIN" ] || [ ! -e "$BLOCK_BIN" ]
    then
      adaptio --build-tests || exit 1
    fi
  }

  case "$COMMAND" in
    build )
      adaptio --build-tests
      ;;
    unit-tests )
      ensure_built
      echo "Running unit tests..."
      "$UNIT_BIN" "${PASS_ARGS[@]}"
      ;;
    block-tests )
      ensure_built
      echo "Running block tests..."
      "$BLOCK_BIN" "${PASS_ARGS[@]}"
      ;;
    quick-block-tests )
      ensure_built
      echo "Running quick block tests..."
      QUICK_BLOCK_TESTS=1 "$BLOCK_BIN" "${PASS_ARGS[@]}"
      ;;
  esac

else
  # Full Nix build fallback (no nix develop environment)
  echo "[dev-test] cmake not found, falling back to nix-test.sh (full build)"
  case "$COMMAND" in
    build )             bash nix-test.sh -b ;;
    unit-tests )        bash nix-test.sh -u -- "${PASS_ARGS[@]}" ;;
    block-tests )       bash nix-test.sh -k -- "${PASS_ARGS[@]}" ;;
    quick-block-tests ) bash nix-test.sh -q -- "${PASS_ARGS[@]}" ;;
  esac
fi
