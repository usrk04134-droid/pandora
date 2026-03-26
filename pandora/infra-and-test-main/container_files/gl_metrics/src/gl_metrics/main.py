#!/usr/bin/env python3
"""Collect GitLab test reports and push to Prometheus Push Gateway."""

import os
import re
import sys
import logging
import argparse
from datetime import datetime

from dotenv import load_dotenv
import gitlab
from prometheus_client import CollectorRegistry, Gauge, push_to_gateway
from prometheus_client.exposition import basic_auth_handler

load_dotenv()

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(levelname)s - %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
)
logger = logging.getLogger(__name__)

FAILURE_REASON_MAX_LEN = 200


def _normalize_failure_reason(value):
    if not value:
        return "(no reason provided)"
    # Flatten multiline traces for table rendering and keep one compact snippet.
    cleaned = re.sub(r"\s+", " ", str(value)).strip()
    if not cleaned:
        return "(no reason provided)"
    return cleaned[:FAILURE_REASON_MAX_LEN]


def _make_gl(args):
    gl = gitlab.Gitlab(
        url=args.gitlab_url,
        private_token=args.gitlab_token,
        ssl_verify=args.gitlab_verify_ssl,
        timeout=args.gitlab_timeout,
    )
    gl.auth()
    return gl


_BROWSER_UA = (
    "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 "
    "(KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36"
)


def _inject_ua(handler):
    """Wrap a push_to_gateway handler to inject a browser-like User-Agent."""
    def _wrapped(url, method, timeout, headers, data):
        headers = [h for h in headers if h[0].lower() != "user-agent"]
        headers.append(("User-Agent", _BROWSER_UA))
        return handler(url, method, timeout, headers, data)
    return _wrapped


def _push(args, registry, grouping_key):
    from prometheus_client.exposition import default_handler
    if args.pushgateway_user and args.pushgateway_password:
        u, p = args.pushgateway_user, args.pushgateway_password

        def base(url, method, timeout, headers, data):
            return basic_auth_handler(url, method, timeout, headers, data, u, p)
    else:
        base = default_handler
    push_to_gateway(
        gateway=args.pushgateway_url.rstrip("/"),
        job=args.pushgateway_job,
        registry=registry,
        grouping_key=grouping_key,
        timeout=args.pushgateway_timeout,
        handler=_inject_ua(base),
    )


def collect_and_push(args, gl, project_id, pipeline_id=None):
    project = gl.projects.get(project_id)

    if pipeline_id:
        pipeline = project.pipelines.get(pipeline_id)
    else:
        filters = {"ref": args.ref} if args.ref else {}
        pipelines = project.pipelines.list(order_by="id", sort="desc", per_page=1, **filters)
        if not pipelines:
            logger.warning("No pipelines found for project %s", project_id)
            return
        pipeline = pipelines[0]

    logger.info("Processing %s pipeline #%s (ref=%s status=%s)",
                project.path_with_namespace, pipeline.id, pipeline.ref, pipeline.status)

    report = pipeline.test_report.get().attributes
    created_dt = datetime.fromisoformat(pipeline.created_at.replace("Z", "+00:00"))
    pipeline_date = created_dt.strftime("%Y-%m-%d")
    px = args.metric_prefix

    base_labels = ["project", "project_id", "pipeline_id", "pipeline_name", "date", "ref", "status", "created_at"]
    base_values = [
        project.path_with_namespace,
        str(project.id),
        str(pipeline.id),
        getattr(pipeline, "name", None) or f"pipeline-{pipeline.id}",
        pipeline_date,
        pipeline.ref,
        pipeline.status,
        str(int(created_dt.timestamp())),
    ]

    registry = CollectorRegistry()

    # Pipeline-level summary metrics
    summary_metrics = [
        ("_test_total",            "Total tests",              "total_count"),
        ("_test_success",          "Successful tests",         "success_count"),
        ("_test_failed",           "Failed tests",             "failed_count"),
        ("_test_skipped",          "Skipped tests",            "skipped_count"),
        ("_test_error",            "Tests with errors",        "error_count"),
        ("_test_duration_seconds", "Test duration in seconds", "total_time"),
    ]
    for suffix, desc, key in summary_metrics:
        Gauge(px + suffix, desc, base_labels, registry=registry).labels(*base_values).set(report.get(key, 0))

    Gauge(f"{px}_pipeline_timestamp", "Pipeline creation Unix timestamp",
          base_labels, registry=registry).labels(*base_values).set(int(created_dt.timestamp()))

    suites = report.get("test_suites", [])

    # Suite-level metrics
    if args.include_suite_metrics and suites:
        s_labels = base_labels + ["suite"]
        g_suite = {
            "total":    Gauge(
                f"{px}_test_suite_total", "Suite total tests", s_labels, registry=registry
            ),
            "failed":   Gauge(
                f"{px}_test_suite_failed", "Suite failed tests", s_labels, registry=registry
            ),
            "skipped":  Gauge(
                f"{px}_test_suite_skipped", "Suite skipped tests", s_labels, registry=registry
            ),
            "error":    Gauge(
                f"{px}_test_suite_error", "Suite errored tests", s_labels, registry=registry
            ),
            "duration": Gauge(
                f"{px}_test_suite_duration_seconds", "Suite duration in seconds",
                s_labels, registry=registry
            ),
        }
        for suite in suites:
            sv = base_values + [suite.get("name", "unknown")]
            g_suite["total"].labels(*sv).set(suite.get("total_count", 0))
            g_suite["failed"].labels(*sv).set(suite.get("failed_count", 0))
            g_suite["skipped"].labels(*sv).set(suite.get("skipped_count", 0))
            g_suite["error"].labels(*sv).set(suite.get("error_count", 0))
            g_suite["duration"].labels(*sv).set(suite.get("total_time", 0.0))

    # Test case metrics: individual results + failure reasons
    if args.include_test_cases and suites:
        tc_labels   = base_labels + ["suite", "classname", "test_name", "test_status"]
        fail_labels = base_labels + ["suite", "classname", "test_name", "failure_reason"]
        g_tc_duration = Gauge(f"{px}_test_case_duration_seconds",
                              "Test case execution time in seconds", tc_labels, registry=registry)
        g_tc_result   = Gauge(f"{px}_test_case_result",
                              "Test case presence indicator (1 per test)", tc_labels, registry=registry)
        g_tc_failure  = Gauge(f"{px}_test_case_failure",
                              "Failed/errored test case with failure reason label", fail_labels, registry=registry)
        for suite in suites:
            suite_name = suite.get("name", "unknown")
            for tc in suite.get("test_cases", []):
                tc_status = tc.get("status", "unknown")
                tc_bv = base_values + [suite_name, tc.get("classname", ""), tc.get("name", ""), tc_status]
                g_tc_duration.labels(*tc_bv).set(tc.get("execution_time", 0.0))
                g_tc_result.labels(*tc_bv).set(1)
                if tc_status in ("failed", "error"):
                    raw = tc.get("system_output") or tc.get("stack_trace") or ""
                    reason = _normalize_failure_reason(raw)
                    fail_bv = base_values + [suite_name, tc.get("classname", ""), tc.get("name", ""), reason]
                    g_tc_failure.labels(*fail_bv).set(tc.get("execution_time", 0.0))

    grouping_key = {
        "group_project": project.path_with_namespace,
        "group_date":    pipeline_date,
    }
    _push(args, registry, grouping_key)

    logger.info("Pushed: %s #%s  total=%s failed=%s duration=%.2fs",
                project.path_with_namespace, pipeline.id,
                report.get("total_count", 0), report.get("failed_count", 0),
                report.get("total_time", 0.0))


def main():
    parser = argparse.ArgumentParser(
        prog="gitlab-metrics",
        description="Collect GitLab test reports and push to Prometheus Push Gateway",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  %(prog)s --project-id 12345
  %(prog)s --project-id 12345 --pipeline-id 67890
  %(prog)s --project-id group/myproject --ref main
  %(prog)s --project-id 12345 --project-id 67890
  %(prog)s --project-id 12345 --include-test-cases true

Environment variables:
  GITLAB_URL, GITLAB_TOKEN, GITLAB_VERIFY_SSL, GITLAB_TIMEOUT
  PUSHGATEWAY_URL, PUSHGATEWAY_USER, PUSHGATEWAY_PASSWORD, PUSHGATEWAY_JOB, PUSHGATEWAY_TIMEOUT
  INCLUDE_SUITE_METRICS, INCLUDE_TEST_CASES, METRIC_PREFIX
        """,
    )
    parser.add_argument("--project-id",  action="append", dest="project_ids", required=True,
                        help="Project ID or path (repeatable)")
    parser.add_argument("--pipeline-id", action="append", dest="pipeline_ids", type=int,
                        help="Pipeline ID (single-project only; omit for latest)")
    parser.add_argument("--ref",         help="Git ref to filter for latest pipeline (e.g. main)")

    parser.add_argument("--gitlab-url",           default=os.getenv("GITLAB_URL", "https://gitlab.com"))
    parser.add_argument("--gitlab-token",         default=os.getenv("GITLAB_TOKEN", ""))
    parser.add_argument(
        "--gitlab-verify-ssl",
        type=lambda x: x.lower() == "true",
        default=os.getenv("GITLAB_VERIFY_SSL", "true").lower() == "true",
    )
    parser.add_argument("--gitlab-timeout", type=int, default=int(os.getenv("GITLAB_TIMEOUT", "30")))

    parser.add_argument("--pushgateway-url",      default=os.getenv("PUSHGATEWAY_URL", "http://localhost:9091"))
    parser.add_argument("--pushgateway-user",     default=os.getenv("PUSHGATEWAY_USER"))
    parser.add_argument("--pushgateway-password", default=os.getenv("PUSHGATEWAY_PASSWORD"))
    parser.add_argument("--pushgateway-job",      default=os.getenv("PUSHGATEWAY_JOB", "gitlab_tests"))
    parser.add_argument("--pushgateway-timeout",  type=int, default=int(os.getenv("PUSHGATEWAY_TIMEOUT", "10")))

    parser.add_argument(
        "--include-suite-metrics",
        type=lambda x: x.lower() == "true",
        default=os.getenv("INCLUDE_SUITE_METRICS", "true").lower() == "true",
        help="Include per-suite metrics (default: true)",
    )
    parser.add_argument(
        "--include-test-cases",
        type=lambda x: x.lower() == "true",
        default=os.getenv("INCLUDE_TEST_CASES", "true").lower() == "true",
        help="Include per-test-case metrics with failure reasons (default: true)",
    )
    parser.add_argument("--metric-prefix",        default=os.getenv("METRIC_PREFIX", "gitlab"),
                                                  help="Metric name prefix (default: gitlab)")
    parser.add_argument("-v", "--verbose",        action="store_true")

    args = parser.parse_args()

    if args.verbose:
        logging.getLogger().setLevel(logging.DEBUG)

    if not args.gitlab_token:
        logger.error("GitLab token required. Set GITLAB_TOKEN or --gitlab-token.")
        sys.exit(1)

    if len(args.project_ids) > 1 and args.pipeline_ids:
        logger.warning("--pipeline-id is ignored when multiple --project-id values are given")

    gl = _make_gl(args)
    failed = 0

    if len(args.project_ids) == 1 and args.pipeline_ids:
        for pid in args.pipeline_ids:
            try:
                collect_and_push(args, gl, args.project_ids[0], pipeline_id=pid)
            except Exception as e:
                logger.error("Pipeline %s failed: %s", pid, e)
                failed += 1
    else:
        for project_id in args.project_ids:
            try:
                collect_and_push(args, gl, project_id)
            except Exception as e:
                logger.error("Project %s failed: %s", project_id, e)
                failed += 1

    if failed:
        sys.exit(1)


if __name__ == "__main__":
    main()
