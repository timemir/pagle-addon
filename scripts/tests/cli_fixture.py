"""A script's command line run in a test: its exit code and everything it printed. The one copy of the helper every
command-line test uses."""

from collections.abc import Callable
from pathlib import Path

import pytest

from pagle_data.cli import main as generate


def run(
    root: Path,
    capsys: pytest.CaptureFixture[str],
    *args: str,
    main: Callable[..., int] = generate,
    **options: object,
) -> tuple[int, str]:
    """main(args, root, **options) on the tree at root, the generator's command line (DATA-R60) unless another
    script's main is given: its exit code and everything it printed, stdout then stderr."""
    code = main(list(args), root, **options)
    out, err = capsys.readouterr()
    return code, out + err
