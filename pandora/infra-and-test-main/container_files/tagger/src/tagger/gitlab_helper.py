from gitlab import GitlabCreateError, GitlabGetError, GitlabListError
from gitlab.base import RESTObjectList
from gitlab.v4.objects import Project

from tagger import logger

NUMBER_OF_REQUIRED_APPROVALS = 1


def create_git_tag(project: Project, commit_sha: str, name: str, message: str) -> bool:
    """Create a git tag.

    Args:
        project (Project): The project object
        commit_sha (str): The commit to tag
        name (str): Name of the tag
        message (str): Message in the tag

    Returns:
        bool: True if the tag was created, False otherwise.
    """

    try:
        _ = project.commits.get(commit_sha)
        logger.debug(f"Reference {commit_sha} found, proceeding with tag creation.")

        _ = project.tags.create({"tag_name": name, "ref": commit_sha, "message": message})
        logger.debug(f"Created tag: {name}, with message '{message}' on '{commit_sha}'")

        return True

    except GitlabGetError:
        logger.exception(f"Reference {commit_sha} does not exist, cannot create tag.")

        return False

    except GitlabCreateError as e:
        logger.exception(f"Failed to create tag: {e.error_message}")

        return False


def create_approval_rule(project: Project, mr_iid: str, rule_name: str, usernames: list[str]) -> bool:
    """Create an approval rule in a merge request.

    Args:
        project (Project): The project object
        mr_iid (str): The project-level IID (internal ID) of the merge request.
        rule_name (str): The rule name to use
        usernames (list[str]): List of usernames to add as approvers

    Returns:
        bool: True if the rule was created or if it already exists, False otherwise.
    """

    # If a rule with the same name already exists in the MR we don't need to create it again
    if approval_rule_exists(project=project, mr_iid=mr_iid, rule_name=rule_name):
        return True

    try:
        mr = project.mergerequests.get(mr_iid)

        approval_rule = mr.approval_rules.create(
            {
                "name": f"{rule_name}",
                "approvals_required": NUMBER_OF_REQUIRED_APPROVALS,
                "usernames": usernames,  # List of usernames as approvers
                "rule_type": "regular",
            }
        )
        logger.debug(f"Created approval rule: {approval_rule.name}")

        return True

    except GitlabCreateError as e:
        logger.exception(f"Failed to create approval rule: {e.error_message}")

        return False


def approval_rule_exists(project: Project, mr_iid: str, rule_name: str) -> bool:
    """Check if a rule with the given name already exist in the merge request.

    Args:
        project (Project): The project object
        mr_iid (str): The project-level IID (internal ID) of the merge request.
        rule_name (str): The rule name to look for

    Returns:
        bool: True if a rule with the same name exists, False otherwise.
    """

    mr = project.mergerequests.get(mr_iid)
    rules = mr.approval_rules.list(all=True)

    exists = any([r for r in rules if rule_name in r.attributes["name"]])
    logger.debug(f"Approval rule exists: {exists}")

    return exists


def get_merge_request_commits(project: Project, mr_iid: str) -> RESTObjectList:
    """Get all commits that are part of a merge request

    Args:
        project (Project): The project object
        mr_iid (str): The project-level IID (internal ID) of the merge request.

    Returns:
        list[RESTObject]: A list of commit objects
    """

    mr = project.mergerequests.get(mr_iid)
    commits = mr.commits(all=True)

    return commits


def add_note_to_merge_request(project: Project, mr_iid: str, message: str) -> bool:
    """Add a note to a merge request.

    Args:
        project (Project): The project object
        mr_iid (str): The project-level IID (internal ID) of the merge request.
        message (str): The message to be added as note in the merge request

    Returns:
        bool: True if the note was added, False otherwise.
    """

    # If a note with the same message already exists in the MR we don't need to create another one
    if note_exists(project=project, mr_iid=mr_iid, message=message):
        return True

    try:
        mr = project.mergerequests.get(mr_iid)
        mr.notes.create({"body": f"{message}"})
        logger.debug(f"Note created with message: {message}")

        return True

    except GitlabCreateError as e:
        logger.exception(f"Failed to add a note the the merge request: {e.error_message}")

        return False


def note_exists(project: Project, mr_iid: str, message: str) -> bool:
    """Check if a note with the same message already exists.

    Args:
        project (Project): The project object
        mr_iid (str): The project-level IID (internal ID) of the merge request.
        message (str): The message to be added as note in the merge request

    Returns:
        bool: True if the message already exists, False otherwise.
    """

    try:
        mr = project.mergerequests.get(mr_iid)
        notes = mr.notes.list(all=True)
        exists = any(note.body == message for note in notes)  # type: ignore
        logger.debug(f"Note exists: {exists}")

        return exists

    except GitlabListError as e:  # type: ignore
        logger.exception(f"Failed to list the merge request notes: {e.error_message}")

        return False
