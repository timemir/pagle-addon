"""A script's command line run in a test: its exit code and everything it printed, and a fetch answering from a
table of URLs. The one copy of each helper every command-line test uses."""

from collections.abc import Callable, Mapping
from pathlib import Path

import pytest

from pagle_data.cli import main as generate


def run_split(
    root: Path,
    capsys: pytest.CaptureFixture[str],
    *args: str,
    main: Callable[..., int] = generate,
    **options: object,
) -> tuple[int, str, str]:
    """main(args, root, **options) on the tree at root, the generator's command line (DATA-R60) unless another
    script's main is given: its exit code, what it printed to stdout and what it printed to stderr."""
    code = main(list(args), root, **options)
    out, err = capsys.readouterr()
    return code, out, err


def run(
    root: Path,
    capsys: pytest.CaptureFixture[str],
    *args: str,
    main: Callable[..., int] = generate,
    **options: object,
) -> tuple[int, str]:
    """run_split, with everything printed in one string, stdout then stderr."""
    code, out, err = run_split(root, capsys, *args, main=main, **options)
    return code, out + err


class Canned:
    """A fetch that answers from a table of URLs and records what was asked."""

    def __init__(self, responses: Mapping[str, bytes]) -> None:
        self.responses = responses
        self.asked: list[str] = []

    def __call__(self, url: str) -> bytes:
        self.asked.append(url)
        if url not in self.responses:
            raise OSError(f"no canned response for {url}")
        return self.responses[url]
