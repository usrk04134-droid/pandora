# Testing and Tool Support in Adaptio

## Code Formatting

### clang-format

- **Tool**: clang-format (Google style)
- **Configuration**: `.clang-format`
- **Scope**: All C++ source files (`src/**/*.cc`, `src/**/*.h`)
- **Pipeline**: Formatting is checked in the `lint` stage via `.gitlab-ci/lints.yml`
- **Command**: `clang-format --Werror --dry-run --verbose src/**/*.cc src/**/*.h`

## Static Code Analysis

### clang-tidy

- **Tool**: clang-tidy
- **Configuration**: `.clang-tidy` and `.clang-tidy-limited` (in CI)
- **Scope**: All C++ source files
- **Checks Enabled**:
   - `bugprone-*`: Bug-prone patterns
   - `clang-analyzer-*`: Static analyzer checks
   - `cppcoreguidelines-*`: C++ Core Guidelines compliance
   - `google-*`: Google style guide checks
   - `readability-*`: Code readability improvements
   - `modernize-*`: Modern C++ practices
   - `performance-*`: Performance optimizations
   - `concurrency-*`: Thread safety checks
- **Local Usage**: Available via `adaptio.sh --check-clang-tidy` and `--fix-clang-tidy`

### Header Inclusion Checks

- **Tool**: clang-tidy `misc-include-cleaner` check
- **Configuration**: Enabled as `WarningsAsErrors` in `.clang-tidy`
- **Purpose**: Ensures all headers are properly included and avoid unused includes
- **Local Usage**: Available via `adaptio.sh --check-includes` and `--fix-includes`

## Dynamic Analysis

### AddressSanitizer (ASan) and UndefinedBehaviorSanitizer (UBSan)

- **Enabled For**: Unit tests and block tests
- **Configuration**:
   - Compile flags: `-fsanitize=address,undefined`
   - Link flags: `-fsanitize=address,undefined`
- **Purpose**:
   - Detects memory errors (use-after-free, buffer overflows)
   - Detects undefined behavior (signed integer overflow, null pointer
     dereferences, etc.)
- **Test Targets**:
   - `adaptio-unit-tests`
   - `adaptio-block-tests`

### Valgrind

- **Tool**: Valgrind (available in development environment)
- **Purpose**: Additional memory error detection and profiling

## Test Types

### Unit Tests

- **Framework**: doctest
- **Target**: `adaptio-unit-tests`
- **Location**: `src/**/test/` directories
- **Scope**: Individual classes
- **Features**:
   - Sanitizers enabled (ASan + UBSan)

### Block Tests (Integration Tests)

- **Framework**: doctest
- **Target**: `adaptio-block-tests`
- **Location**: `src/block_tests/`
- **Scope**: Integration tests on message interfaces
- **Features**:
   - Sanitizers enabled (ASan + UBSan)
   - Deposition simulator for realistic testing

## Pipeline Testing

The GitLab CI pipeline (`.gitlab-ci.yml`) includes the following test stages:

### Lint Stage

- **clang-format**: Format checking (runs on merge requests when C++ files change)
- **Python linting**: Ruff linter for Python scripts
- **Markdown linting**: markdownlint-cli2 for documentation
- **Shell script linting**: ShellCheck for shell scripts
- **Commit message linting**: Conventional commit format checking

### Build Stage

- **Build**: Compiles the main application
- **Build Tests**: Compiles unit tests and block tests

### Test Stage

- **Unit Tests** (`unit-tests` job):
   - Runs `adaptio-unit-tests` target
   - Generates XML report: `unit-tests-report.xml`

- **Block Tests** (`block-tests` job):
   - Runs `adaptio-block-tests` target
   - Generates XML report: `block-tests-report.xml`

### Additional Checks

- **Nix flake checks**: Validates Nix build configuration
- **Version linting**: Ensures semantic versioning compliance
- **Semantic versioning**: Automated version bumping on protected branches

## Local Test Execution

```bash
# Build tests
adaptio --build-tests

# Run unit tests
adaptio --unit-tests

# Run block tests
adaptio --block-tests

# Run with filters
./build/debug/src/adaptio-block-tests --doctest-test-case="test_name*"

# Run with sanitizers (enabled by default for tests)
./build/debug/src/adaptio-unit-tests
```
