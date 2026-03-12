# Pipeline templates and scripts

## Description

In this directory we keep all things pipeline related.

## Table of Contents

- [Pipeline templates and scripts](#pipeline-templates-and-scripts)
   - [Description](#description)
   - [Table of Contents](#table-of-contents)
   - [GitLab documentation](#gitlab-documentation)
   - [Structure \& logging](#structure--logging)
      - [Logging](#logging)
      - [Sections](#sections)
   - [Shell scripts](#shell-scripts)
      - [Fetch scripts in pipeline jobs](#fetch-scripts-in-pipeline-jobs)
   - [Pipeline templates and scripts](#pipeline-templates-and-scripts-1)
   - [Linting related jobs](#linting-related-jobs)
      - [Markdown linting](#markdown-linting)
      - [Nix linting](#nix-linting)
   - [PLC related jobs](#plc-related-jobs)
      - [Building aws-platform test environment](#building-aws-platform-test-environment)
      - [Building PLC software](#building-plc-software)
      - [Testing the PLC software](#testing-the-plc-software)
      - [Deploying the PLC software](#deploying-the-plc-software)

## GitLab documentation

[Gitlab spec][gitlab-spec] \
[Gitlab rules][gitlab-rules] \
[Gitlab jobs][gitlab-jobs] \
[Gitlab when][gitlab-when] \
[Gitlab matrix][gitlab-matrix] \
[Gitlab needs][gitlab-needs] \
[Gitlab sections][gitlab-job-log-sections]

## Structure & logging

In order to get the same look and feel in the pipeline jobs it is recommended to use our custom logging and section functions. \
For inline pipeline job scripts you can "import" these functions by sourcing `$GITLAB_SHARED_FUNCS` in one of the script parts of the job.

`GITLAB_SHARED_FUNCS` is defined in [gl_main.tf](../infrastructure/terraform/gl_main.tf) and is created as a group variable that will be available for all pipeline jobs.

For standalone shell scripts we instead source [logger.sh](scripts/logger.sh) to get access to the same functions. \
The functions defined in `logger.sh` comes with the additional options to use `QUIET` or `VERBOSE` logging. \
If quiet, no logs will be printed, and if verbose, `DEBUG` level logs will be printed. By default only `INFO`, `WARN` and `ERROR` level logs are printed.

### Logging

Example of how to use the logging functions in a pipeline job:

```bash
example-job:
  before_script:
    - source $GITLAB_SHARED_FUNCS
  script:
    - log_info "This will log INFO level message in GREEN color"
    - log_debug "This will log DEBUG level message in BLUE color"
    - log_warn "This will log WARN level message in YELLOW color"
    - log_error "This will log ERROR level message in RED color"
```

Example of how to "import" and use the logging functions in a standalone shell script:

```bash
# Source the logger module - assuming it's in the same directory
SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
source "${SCRIPT_DIR}/logger.sh"

log_info "This will log INFO level message in GREEN color"
log_debug "This will log DEBUG level message in BLUE color"
log_warn "This will log WARN level message in YELLOW color"
log_error "This will log ERROR level message in RED color"
```

### Sections

In Gitlab job logs are divided into [sections][gitlab-job-log-sections] that can be collapsed or expanded. Each section displays the duration.

By using sections we can improve the structure of the job logs.
We will also get a time duration for each section, making it easier to understand what is causing the duration of a job.

Example of how to use the sections functions in a pipeline job:

```bash
example-job:
  before_script:
    - source $GITLAB_SHARED_FUNCS
  script:
    - section_start title "Description of what this section does"
    - log_info "This is a section"
    - section_end title
```

Sometimes job logs can become quite large. By using collapsed sections these lines can be hidden by default. \
The way to make a section collapsed is to add a third argument to the `section_start` function. \
It doesn't really matter what that argument is, the section will be collapsed simply because a third argument exists, regardless of its value.

Example of how to use the collapsed sections functions in a pipeline job:

```bash
section_start title "Description of what this section does" collapsed
log_info "This is a collapsed section"
section_end title
```

Sections can also be nested, i.e., a section within a section.

> [!note]
> Sections is a Gitlab feature and when used in a shell script, they will only appear as intended when the script is executed in a Gitlab environment.

## Shell scripts

When the script logic required by a job becomes complex enough (use your judgment), it shall be implemented as a standalone shell script. \
This is also true for script code that can be reused in different jobs. Avoid code duplication when possible.

Scripts used by pipeline jobs are placed here: [scripts](./scripts)

### Fetch scripts in pipeline jobs

To make scripts available in a pipeline job, include the [fetch-scripts.yml](fetch-scripts.yml) template.

```YAML
include:
  - local: '/.gitlab-ci/fetch-scripts.yml'
```

and reference it from the job that needs it.

```YAML
    - !reference [.fetch-scripts, script]
```

The `fetch-scripts.yml` template will download all the scripts and export an environment variable `SCRIPTS_DIR`, that contains the path.

> [!important]
> Most of the scripts have some dependency on the environment.\
> Just because a script is available doesn't mean it can be run in any given pipeline job. It will depend on the container image used by that job.

## Pipeline templates and scripts

## Linting related jobs

### Markdown linting

For linting markdown we use the [markdownlint-cli2][markdownlint-cli2] tool.

The configuration that is used can be found here: [.markdownlint-cli2.yaml][markdownlint-cli2-config].

> [!note]
> The job can be told to use a custom config by pointing the input argument `use-config` to a local markdownlint-cli2 config file.

The pipeline job template can be found here: [lint-markdown-cli2.yml][lint-markdown-cli2]

[markdownlint-cli2]: https://github.com/DavidAnson/markdownlint-cli2
[markdownlint-cli2-config]: https://gitlab.com/esab/abw/infra-and-test/-/tree/main/container_files/markdownlint_cli2/.markdownlint-cli2.yaml
[lint-markdown-cli2]: lint-markdown-cli2.yml

### Nix linting

For linting Nix files we use [nixfmt-rfc-style][nixfmt] to ensure consistent formatting according to RFC style guidelines.

The pipeline job template can be found here: [lint-nix.yml][lint-nix]

> [!note]
> The job can be told to exclude specific directories or files by using the `exclude-paths` input argument.

Example usage with exclusions:

```yaml
- template: .gitlab-ci/lint-nix.yml
  inputs:
    exclude-paths:
      - container_files/nix-stored
      - hil-os/targets
```

[nixfmt]: https://github.com/NixOS/nixfmt
[lint-nix]: lint-nix.yml

## PLC related jobs

### Building aws-platform test environment

The [build-and-push-flake.yml][build-and-push-flake] template is used to create the aws-platform test environment image. This template accepts the following inputs.

- job-name
- job-matrix
- job-rules
- nix-attributes

The template uses [podman][podman_infra-and-test] image from infra-and-test container registry to build the test environment. In a container of the aws-platform image, we can build and test the PLC software.

### Building PLC software

The [plc-apax-build.yml][plc-apax-build] template is used to build the PLC software. This template accepts the following inputs.

- job-name
- job-matrix
- job-rules
- image-version
- login-token

It uses the [aws-platform-env] image to build the PLC software.

The `job-matrix` input is a list of PLC configurations to build (specified as PLC_CONFIG). If PLC_CONFIG is not set, the job will build a minimal base system configuration, which can be achieved by setting PLC_CONFIG to an empty string.

### Testing the PLC software

The [plc-apax-test.yml][plc-apax-test] template is used to test the PLC software. This template accepts the following inputs.

- job-name
- job-rules
- image-version
- login-token

It uses the [aws-platform-env] image to test the PLC software.

An AxUnit test report is created in `${CI_PROJECT_DIR}/bin/axunit-artifacts/test-results/TestResult.xml`at the end of the test execution. As Gitlab does not understand this format, we convert it into a Junit report.

### Deploying the PLC software

This feature is not implemented yet. It might be possible to do using [TIA Portal Openess][tia-portal-openness] or `Apax`. More details will be provided after the completion of [ADT-1177](https://esabgrnd.jira.com/jira/software/c/projects/ADT/boards/590/backlog?selectedIssue=ADT-1177)

[podman_infra-and-test]: https://gitlab.com/esab/abw/infra-and-test/container_registry/6693662
[build-and-push-flake]: https://gitlab.com/esab/abw/infra-and-test/-/blob/main/.gitlab-ci/build-and-push-flake.yml?ref_type=heads
[plc-apax-build]: https://gitlab.com/esab/abw/infra-and-test/-/blob/main/.gitlab-ci/plc-apax-build.yml?ref_type=heads
[plc-apax-test]: https://gitlab.com/esab/abw/infra-and-test/-/blob/main/.gitlab-ci/plc-apax-test.yml?ref_type=heads
[aws-platform-env]: https://gitlab.com/esab/abw/plc/aws-platform/container_registry/8500769
[tia-portal-openness]: https://support.industry.siemens.com/cs/se/en/view/109792902

[gitlab-spec]: https://docs.gitlab.com/ci/yaml/#spec
[gitlab-rules]: https://docs.gitlab.com/ci/yaml/#rules
[gitlab-jobs]: https://docs.gitlab.com/ci/jobs/#add-a-job-to-a-pipeline
[gitlab-when]: https://docs.gitlab.com/ci/yaml/#when
[gitlab-matrix]: https://docs.gitlab.com/ci/yaml/#parallelmatrix
[gitlab-needs]: https://docs.gitlab.com/ci/yaml/#needs
[gitlab-job-log-sections]: https://docs.gitlab.com/ci/jobs/job_logs/#expand-and-collapse-job-log-sections
