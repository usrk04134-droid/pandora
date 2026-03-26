# gl_metrics

Collects GitLab CI test reports and pushes them as metrics to a [Prometheus Pushgateway](https://github.com/prometheus/pushgateway).

## How it works

For each given project, it fetches the latest pipeline's test report from the GitLab API and pushes Prometheus `Gauge` metrics to the Pushgateway. Optionally includes per-suite and per-test-case breakdown with failure reasons.

## Docker usage

```sh
docker run --rm \
  -e GITLAB_TOKEN=<your-token> \
  -e PUSHGATEWAY_URL=http://pushgateway:9091 \
  -e GITLAB_URL=https://gitlab.com \
  gl_metrics \
  --project-id <project-id-or-path>
```

## Configuration

All options can be set via environment variables or CLI flags. CLI flags take precedence.

### GitLab

| Env var              | CLI flag              | Default                | Description                        |
|----------------------|-----------------------|------------------------|------------------------------------|
| `GITLAB_URL`         | `--gitlab-url`        | `https://gitlab.com`   | GitLab instance URL                |
| `GITLAB_TOKEN`       | `--gitlab-token`      | *(required)*           | Personal or project access token   |
| `GITLAB_VERIFY_SSL`  | `--gitlab-verify-ssl` | `true`                 | Verify TLS certificates            |
| `GITLAB_TIMEOUT`     | `--gitlab-timeout`    | `30`                   | Request timeout in seconds         |

### Pushgateway

| Env var                | CLI flag                 | Default                    | Description                          |
|------------------------|--------------------------|----------------------------|--------------------------------------|
| `PUSHGATEWAY_URL`      | `--pushgateway-url`      | `http://localhost:9091`    | Pushgateway URL                      |
| `PUSHGATEWAY_USER`     | `--pushgateway-user`     | *(none)*                   | Basic auth username                  |
| `PUSHGATEWAY_PASSWORD` | `--pushgateway-password` | *(none)*                   | Basic auth password                  |
| `PUSHGATEWAY_JOB`      | `--pushgateway-job`      | `gitlab_tests`             | Job label in Pushgateway             |
| `PUSHGATEWAY_TIMEOUT`  | `--pushgateway-timeout`  | `10`                       | Push timeout in seconds              |

### Metrics

| Env var                 | CLI flag                  | Default    | Description                                             |
|-------------------------|---------------------------|------------|---------------------------------------------------------|
| `METRIC_PREFIX`         | `--metric-prefix`         | `gitlab`   | Prefix for all metric names                             |
| `INCLUDE_SUITE_METRICS` | `--include-suite-metrics` | `true`     | Include per-test-suite breakdown                        |
| `INCLUDE_TEST_CASES`    | `--include-test-cases`    | `false`    | Include per-test-case metrics with failure reason label |

## Examples

```sh
# Latest pipeline for a project (by numeric ID)
docker run --rm -e GITLAB_TOKEN=xxx -e PUSHGATEWAY_URL=http://pushgateway:9091 \
  gl_metrics --project-id 12345

# Latest pipeline on a specific branch
docker run --rm -e GITLAB_TOKEN=xxx -e PUSHGATEWAY_URL=http://pushgateway:9091 \
  gl_metrics --project-id group/myproject --ref main

# A specific pipeline
docker run --rm -e GITLAB_TOKEN=xxx -e PUSHGATEWAY_URL=http://pushgateway:9091 \
  gl_metrics --project-id 12345 --pipeline-id 67890

# Multiple projects at once
docker run --rm -e GITLAB_TOKEN=xxx -e PUSHGATEWAY_URL=http://pushgateway:9091 \
  gl_metrics --project-id 12345 --project-id 67890

# Enable per-test-case metrics
docker run --rm -e GITLAB_TOKEN=xxx -e PUSHGATEWAY_URL=http://pushgateway:9091 \
  gl_metrics --project-id 12345 --include-test-cases true
```

## Metrics reference

All metrics are prefixed with `METRIC_PREFIX` (default: `gitlab`).

### Pipeline summary (always emitted)

| Metric                            | Description                         |
|-----------------------------------|-------------------------------------|
| `gitlab_test_total`               | Total test count                    |
| `gitlab_test_success`             | Successful test count               |
| `gitlab_test_failed`              | Failed test count                   |
| `gitlab_test_skipped`             | Skipped test count                  |
| `gitlab_test_error`               | Errored test count                  |
| `gitlab_test_duration_seconds`    | Total test duration in seconds      |
| `gitlab_pipeline_timestamp`       | Pipeline creation Unix timestamp    |

Common labels: `project`, `project_id`, `pipeline_id`, `pipeline_name`, `date`, `ref`, `status`, `created_at`.

### Per-suite (`--include-suite-metrics true`, default on)

| Metric                                  | Description                    |
|-----------------------------------------|--------------------------------|
| `gitlab_test_suite_total`               | Suite total test count         |
| `gitlab_test_suite_failed`              | Suite failed count             |
| `gitlab_test_suite_skipped`             | Suite skipped count            |
| `gitlab_test_suite_error`               | Suite errored count            |
| `gitlab_test_suite_duration_seconds`    | Suite duration in seconds      |

Additional label: `suite`.

### Per-test-case (`--include-test-cases true`, default off)

| Metric                                 | Description                                   |
|----------------------------------------|-----------------------------------------------|
| `gitlab_test_case_duration_seconds`    | Individual test execution time                |
| `gitlab_test_case_result`             | Presence indicator (always 1)                 |
| `gitlab_test_case_failure`            | Failed/errored test with `failure_reason` label |

Additional labels: `suite`, `classname`, `test_name`, `test_status` / `failure_reason`.
