"""Text written into Markdown: the GitHub issues and comments the scripts write (DATA-R117, DATA-R128)."""

import re


def md_text(text: str) -> str:
    """text with the characters Markdown would act on escaped, so a DB2 name shows as written."""
    return re.sub(r"([\\`*_\[\]<>|~])", r"\\\1", text)
