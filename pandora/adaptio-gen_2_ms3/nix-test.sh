#!/usr/bin/env bash

# Builds and runs Adaptio tests using nix build, without requiring a nix develop shell.
# Test binaries are written to result-tests/ (a symlink into the Nix store).
# See docs/build-without-nix-develop.md for rationale and trade-offs.

if [ ! -e nix-test.sh ]
then
  echo "Script must be run in root project directory."
  exit 1
fi

COMMAND=""

usage() {
  echo "Usage: $(basename "$0") [OPTIONS] [-- <test runner args>]"
  echo "Options:"
  echo "  -h, --help              Display this help message"
  echo "  -b, --build             Build test binaries via nix build"
  echo "  -u, --unit-tests        Run unit tests (builds first if needed)"
  echo "  -k, --block-tests       Run block tests (builds first if needed)"
  echo "  -q, --quick-block-tests Run block tests excluding slow suite (builds first if needed)"
  echo ""
  echo "Examples:"
  echo "  $(basename "$0") --build"
  echo "  $(basename "$0") --unit-tests"
  echo "  $(basename "$0") --quick-block-tests"
  echo "  $(basename "$0") --block-tests -- --test-case=\"my test\""
}

if [ $# -eq 0 ]
then
  usage
  exit 1
fi

while [ $# -gt 0 ]
do
  case "$1" in
    -h | --help )             usage; exit 0 ;;
    -b | --build )            COMMAND="build" ;;
    -u | --unit-tests )       COMMAND="unit-tests" ;;
    -k | --block-tests )      COMMAND="block-tests" ;;
    -q | --quick-block-tests ) COMMAND="quick-block-tests" ;;
    -- ) shift; break ;;
    * ) echo "Unknown argument: $1"; echo ""; usage; exit 1 ;;
  esac
  shift
done

build_tests() {
  echo "Building adaptio-tests..."
  nix build .#adaptio-tests --out-link result-tests
}

ensure_built() {
  if [ ! -e result-tests ]
  then
    build_tests || exit 1
  fi
}

case "$COMMAND" in
  build )
    build_tests
    ;;
  unit-tests )
    ensure_built
    echo "Running unit tests..."
    ./result-tests/bin/adaptio-unit-tests "$@"
    ;;
  block-tests )
    ensure_built
    echo "Running block tests..."
    ./result-tests/bin/adaptio-block-tests "$@"
    ;;
  quick-block-tests )
    ensure_built
    echo "Running quick block tests..."
    QUICK_BLOCK_TESTS=1 ./result-tests/bin/adaptio-block-tests "$@"
    ;;
esac
