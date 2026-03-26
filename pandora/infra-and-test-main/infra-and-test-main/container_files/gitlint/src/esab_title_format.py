"""File implementing ESAB4 gitlint rule."""

# THIS SOURCE IS CONFIDENTIAL AND PROPRIETARY TO THE ESAB GROUP OF COMPANIES
# AND MAY NOT BE REPRODUCED, PUBLISHED OR DISCLOSED TO OTHERS WITHOUT ESAB
# AUTHORISATION. COPYRIGHT (c) ESAB AB 2015- . THIS WORK IS UNPUBLISHED.
# ESAB AB DOES NOT WARRANT OR ASSUME ANY LEGAL LIABILITY OR RESPONSIBILITY FOR
# THE ACCURACY, COMPLETENESS, USEFULNESS, OR COMMERCIAL ABILITY OF THIS SOURCE.
import re
from gitlint.rules import LineRule, RuleViolation, CommitMessageTitle
from gitlint.options import IntOption


class TitleFormat(LineRule):
    """Rule enforcing subject capitalization and max line count to 50."""

    id = "ESAB4"
    name = "title-format"

    target = CommitMessageTitle

    # A rule MAY have an option_spec if its behavior should be configurable.
    options_spec = [IntOption("line-count", 50, "Maximum body line count")]

    def validate(self, title, _commit):
        """Check Subject Maximum Line Count & subject is capitalized."""
        violations = []
        # title = commit.message.title
        char = ": "
        pattern = ".+?" + char
        subject = re.sub(pattern, '', title, 1)

        if not subject[0].isupper():
            msg = "subject does not start with a capital letter"
            violations.append(RuleViolation(self.id, msg, subject))

        # Full title (including type) should not exceed <setting> chars
        count = len(title)
        line_count = self.options["line-count"].value
        if count > line_count:
            msg = f"title contains too many characters ({count} > {line_count})"
            violations.append(RuleViolation(self.id, msg, title))

        return violations
