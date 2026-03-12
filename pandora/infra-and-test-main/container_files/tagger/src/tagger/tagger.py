import os
from pathlib import Path

import click
from git import InvalidGitRepositoryError, NoSuchPathError, Repo
from gitlab import Gitlab

from tagger import logger
from tagger.common import (
    analyze_merge_commit,
    analyze_merge_request,
    analyze_multiple_merge_commits,
    bump_semver_version,
)
from tagger.gitlab_helper import (
    add_note_to_merge_request,
    create_approval_rule,
    create_git_tag,
)
from tagger.utils import write_file


@click.group(context_settings={"max_content_width": 120, "show_default": True, "help_option_names": ["-h", "--help"]})
@click.pass_context
def cli(ctx: click.Context) -> None:
    # ensure that ctx.obj exists and is a dict
    ctx.ensure_object(dict)

    current_dir = Path.cwd().resolve()

    try:
        repo = Repo(current_dir, search_parent_directories=True)
        ctx.obj["repo"] = repo
    except (InvalidGitRepositoryError, NoSuchPathError) as exc:
        message = f"'{current_dir}' is not a valid Git repository path"
        logger.exception(message)
        raise click.UsageError(message) from exc

    project_id = os.environ.get("CI_PROJECT_ID", "")
    token = os.environ.get("SERVICE_ACCOUNT_PAT", "")
    gitlab_url = os.environ.get("CI_SERVER_URL", "")

    if not project_id:
        message = "ENV variabale 'CI_PROJECT_ID' is not set or is empty."
        logger.error(message)
        raise click.UsageError(message)

    if not token:
        message = "ENV variable 'SERVICE_ACCOUNT_PAT' is not set or is empty."
        logger.error(message)
        raise click.UsageError(message)

    if not gitlab_url:
        message = "ENV variable 'CI_SERVER_URL' is not set or is empty."
        logger.error(message)
        raise click.UsageError(message)

    gl_instance = Gitlab(
        url=gitlab_url,
        private_token=token,
        retry_transient_errors=True,
    )

    project = gl_instance.projects.get(project_id, lazy=True)
    ctx.obj["project"] = project


@click.group()
def analyze():
    """Analyze merge commits, or merge requests."""


@click.command("merge-commit")
@click.argument("commit_sha", required=True)
@click.option("--pre-release", is_flag=True, help="Override and bump the pre-release version")
@click.option("--dotenv", is_flag=True, help="Output to tagger.env")
@click.pass_context
def merge_commit(ctx, commit_sha, pre_release, dotenv):
    """Analyze a single merge commit."""
    repo = ctx.obj["repo"]

    next_version, bump_name, bump_type = analyze_merge_commit(
        repo=repo,
        commit_sha=commit_sha,
        pre_release=pre_release,
    ) or ("", "", "")

    handle_output(next_version, bump_name, bump_type, dotenv)


@click.command("multiple-merge-commits")
@click.argument("new_commit_sha", required=True)
@click.argument("old_commit_sha", required=True)
@click.option("--pre-release", is_flag=True, help="Override and bump the pre-release version")
@click.option("--dotenv", is_flag=True, help="Output to tagger.env")
@click.pass_context
def multiple_merge_commits(ctx, new_commit_sha, old_commit_sha, pre_release, dotenv):
    """Analyze all merge commits between two commits."""
    repo = ctx.obj["repo"]

    next_version, bump_name, bump_type = analyze_multiple_merge_commits(
        repo=repo,
        new_commit_sha=new_commit_sha,
        old_commit_sha=old_commit_sha,
        pre_release=pre_release,
    ) or ("", "", "")

    handle_output(next_version, bump_name, bump_type, dotenv)


@click.command("merge-request")
@click.argument("commit_sha", required=True)
@click.option("--pre-release", is_flag=True, help="Override and bump the pre-release version")
@click.option("--dotenv", is_flag=True, help="Output to tagger.env")
@click.pass_context
def merge_request(ctx, commit_sha, pre_release, dotenv):
    """Analyze a merge request."""
    repo = ctx.obj["repo"]
    project = ctx.obj["project"]

    mr_iid = os.environ.get("CI_MERGE_REQUEST_IID", "")
    if not mr_iid:
        message = "ENV variable 'CI_MERGE_REQUEST_IID' is not set or is empty."
        logger.error(message)
        raise click.UsageError(message)

    next_version, bump_name, bump_type = analyze_merge_request(
        repo=repo,
        project=project,
        mr_iid=mr_iid,
        commit_sha=commit_sha,
        pre_release=pre_release,
    ) or ("", "", "")

    handle_output(next_version, bump_name, bump_type, dotenv)


def handle_output(next_version, bump_name, bump_type, dotenv):
    """Handles output and dotenv file writing."""
    if dotenv:
        dotenv_data = [
            f"SEMVER_VERSION={next_version}",
            f"SEMVER_BUMP={bump_name}",
            f"SEMVER_TYPE={bump_type}",
        ]
        _ = write_file("tagger.env", "\n".join(dotenv_data) + "\n")

    # End marker
    logger.info("╔══════════════════════════════════════════════════════════════════╗")
    logger.info("║                      ANALYSIS COMPLETE                           ║")
    logger.info("╚══════════════════════════════════════════════════════════════════╝")

    if bump_name and next_version:
        click.echo(f"New '{bump_name}' version '{next_version}' due to a '{bump_type}' change")
    elif bump_name and not next_version:
        click.echo("No previous version found! Initial version (0.1.0) must be created manually.")
    else:
        click.echo("No new version needed")


@click.group()
def add() -> None:
    """Add a tag, approval rule, or note to a merge request."""


@click.command("tag")
@click.argument("commit_sha")
@click.argument("name")
@click.argument("message")
@click.pass_context
def add_tag(ctx: click.Context, commit_sha, name, message) -> None:
    project = ctx.obj["project"]

    created = create_git_tag(project, commit_sha, name, message)

    if not created:
        message = f"Failed to create tag '{name}' on '{commit_sha}'"
        logger.error(message)
        raise click.ClickException(message)


@click.command("approval")
@click.argument("mr_iid")
@click.argument("name")
@click.argument("usernames", nargs=-1)
@click.pass_context
def add_approval(ctx: click.Context, mr_iid, name, usernames) -> None:
    project = ctx.obj["project"]

    added = create_approval_rule(project=project, mr_iid=mr_iid, rule_name=name, usernames=list(usernames))

    if not added:
        message = f"Failed to add approval rule '{name}' to merge request '{mr_iid}'"
        logger.error(message)
        raise click.ClickException(message)


@click.command("note")
@click.argument("mr_iid")
@click.argument("message")
@click.pass_context
def add_note(ctx: click.Context, mr_iid, message) -> None:
    project = ctx.obj["project"]

    added = add_note_to_merge_request(project=project, mr_iid=mr_iid, message=message)

    if not added:
        message = f"Failed to add a note to merge request '{mr_iid}'"
        logger.error(message)
        raise click.ClickException(message)


@click.group()
def calculate() -> None:
    """Calculate next version based on current version and bump name."""


@click.command("version")
@click.argument("current_version", required=True)
@click.argument("bump_name", required=True)
@click.option("--dotenv", is_flag=True, help="Output to tagger.env")
def calculate_version(current_version, bump_name, dotenv) -> None:
    next_version, bump_name = bump_semver_version(current_version, bump_name.upper())

    if not next_version:
        message = f"Failed to calculate new version for '{current_version}' by '{bump_name}'"
        logger.error(message)
        raise click.ClickException(message)

    handle_output(next_version, bump_name, "", dotenv)


cli.add_command(analyze)
analyze.add_command(merge_commit)
analyze.add_command(multiple_merge_commits)
analyze.add_command(merge_request)

cli.add_command(add)
add.add_command(add_tag)
add.add_command(add_approval)
add.add_command(add_note)

cli.add_command(calculate)
calculate.add_command(calculate_version)
