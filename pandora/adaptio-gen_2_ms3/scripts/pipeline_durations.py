#!/usr/bin/env python3
"""
Fetch and tabulate CI pipeline durations for merge requests.

For each MR the most recent pipeline is shown (the one that ran on
the final push before merge/close). Token is read from the
GITLAB_TOKEN environment variable.

Usage:
    python3 pipeline_durations.py [--count N] [--state STATE] [--jobs]

Options:
    --count N       Number of recent MRs to fetch (default: 20)
    --state STATE   MR state filter: merged, opened, closed, all (default: all)
    --jobs          Also show per-job duration breakdown
"""

import argparse
import os
import sys
import urllib.request
import urllib.error
import json
from datetime import datetime


PROJECT = "esab%2Fabw%2Fadaptio"
BASE_URL = f"https://gitlab.com/api/v4/projects/{PROJECT}"


def read_token() -> str:
    token = os.environ.get("GITLAB_TOKEN", "").strip()
    if not token:
        sys.exit("Error: GITLAB_TOKEN environment variable is not set or empty")
    return token


def api_get(url: str, token: str) -> object:
    req = urllib.request.Request(url, headers={"PRIVATE-TOKEN": token})
    try:
        with urllib.request.urlopen(req) as resp:
            return json.load(resp)
    except urllib.error.HTTPError as e:
        body = e.read().decode()
        sys.exit(f"HTTP {e.code} for {url}: {body}")



def fmt_duration(seconds: int | float | None) -> str:
    if seconds is None:
        return "—"
    m, s = divmod(int(seconds), 60)
    return f"{m}m{s:02d}s"


def fmt_time(iso: str | None) -> str:
    if not iso:
        return "—"
    dt = datetime.fromisoformat(iso.replace("Z", "+00:00"))
    return dt.astimezone().strftime("%Y-%m-%d %H:%M")


def fetch_mrs(token: str, count: int, state: str) -> list[dict]:
    return api_get(
        f"{BASE_URL}/merge_requests?state={state}&per_page={count}"
        f"&order_by=updated_at&sort=desc",
        token,
    )


def last_pipeline(token: str, mr_iid: int) -> dict | None:
    pipelines = api_get(
        f"{BASE_URL}/merge_requests/{mr_iid}/pipelines?per_page=1",
        token,
    )
    if not pipelines:
        return None
    p = pipelines[0]
    return api_get(f"{BASE_URL}/pipelines/{p['id']}", token)


def fetch_jobs(token: str, pipeline_id: int) -> list[dict]:
    return api_get(f"{BASE_URL}/pipelines/{pipeline_id}/jobs?per_page=100", token)


def print_pipeline_table(rows: list[tuple[dict, dict | None]]) -> None:
    col_mr    = max(len("MR"),       max(len(str(mr["iid"])) for mr, _ in rows))
    col_date  = 16
    col_status = max(len("Status"),  max(len((p["status"] if p else "no pipeline")) for _, p in rows))
    col_dur   = max(len("Duration"), max(len(fmt_duration(p["duration"] if p else None)) for _, p in rows))
    col_title = 45

    header = (
        f"{'MR':<{col_mr}}  "
        f"{'Started':<{col_date}}  "
        f"{'Status':<{col_status}}  "
        f"{'Duration':>{col_dur}}  "
        f"Title"
    )
    sep = "-" * (len(header) + col_title)
    print(sep)
    print(header)
    print(sep)

    durations = []
    for mr, p in rows:
        dur = p["duration"] if p else None
        status = p["status"] if p else "no pipeline"
        started = p.get("started_at") if p else None
        if dur is not None:
            durations.append(dur)
        title = mr["title"]
        if len(title) > col_title:
            title = title[: col_title - 1] + "…"
        print(
            f"{str(mr['iid']):<{col_mr}}  "
            f"{fmt_time(started):<{col_date}}  "
            f"{status:<{col_status}}  "
            f"{fmt_duration(dur):>{col_dur}}  "
            f"{title}"
        )
    print(sep)
    if durations:
        avg = sum(durations) / len(durations)
        print(
            f"  avg {fmt_duration(avg)}"
            f"   min {fmt_duration(min(durations))}"
            f"   max {fmt_duration(max(durations))}"
            f"   ({len(durations)} pipelines)"
        )
    print()


def print_job_table(token: str, rows: list[tuple[dict, dict | None]]) -> None:
    valid = [(mr, p) for mr, p in rows if p]
    if not valid:
        return

    all_names: list[str] = []
    pipeline_jobs: list[list[dict]] = []
    for _, p in valid:
        jobs = fetch_jobs(token, p["id"])
        pipeline_jobs.append(jobs)
        for j in jobs:
            if j["name"] not in all_names:
                all_names.append(j["name"])

    iids = [str(mr["iid"]) for mr, _ in valid]
    col_name = max(len("Job"), max(len(n) for n in all_names))
    col_w = max(8, max(len(iid) for iid in iids))

    header = f"{'Job':<{col_name}}" + "".join(f"  {iid:>{col_w}}" for iid in iids)
    sep = "-" * len(header)
    print("Per-job durations (most recent pipeline per MR):")
    print(sep)
    print(header)
    print(sep)
    for name in all_names:
        vals = []
        for jobs in pipeline_jobs:
            by_name = {j["name"]: j for j in jobs}
            j = by_name.get(name)
            vals.append(fmt_duration(j.get("duration") if j else None))
        print(f"{name:<{col_name}}" + "".join(f"  {v:>{col_w}}" for v in vals))
    print(sep)
    print()


def main() -> None:
    parser = argparse.ArgumentParser(description="GitLab MR pipeline duration report")
    parser.add_argument("--count", type=int, default=20, metavar="N",
                        help="Number of recent MRs to fetch (default: 20)")
    parser.add_argument("--state", default="all",
                        choices=["merged", "opened", "closed", "all"],
                        help="MR state filter (default: all)")
    parser.add_argument("--jobs", action="store_true",
                        help="Also show per-job duration breakdown")
    args = parser.parse_args()

    token = read_token()

    print(f"Fetching {args.count} most recent {args.state} MRs…")
    mrs = fetch_mrs(token, args.count, args.state)

    rows: list[tuple[dict, dict | None]] = []
    for mr in mrs:
        p = last_pipeline(token, mr["iid"])
        rows.append((mr, p))

    print_pipeline_table(rows)

    if args.jobs:
        print_job_table(token, rows)


if __name__ == "__main__":
    main()
