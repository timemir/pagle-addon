"""Where a problem in data/ sits and how problems are collected (DATA-R63): every script reports through these,
whatever it reads (TOML, CSV, DB2 downloads), so one run lists every problem before it fails."""

import sys
from collections.abc import Iterable, Iterator
from dataclasses import dataclass, field


@dataclass(frozen=True)
class At:
    """Where a value sits: a file relative to the repo root (or a URL or a command-line argument a script was given)
    and a dotted key path inside it."""

    file: str
    path: str = ""

    def __truediv__(self, key: str) -> "At":
        return At(self.file, f"{self.path}.{key}" if self.path else key)

    def __str__(self) -> str:
        return f"{self.file}: {self.path}" if self.path else self.file


@dataclass
class Problems:
    """The problems found so far, in the order found."""

    found: list[str] = field(default_factory=list)

    def add(self, at: At, message: str) -> None:
        self.found.append(f"{at}: {message}")

    def __bool__(self) -> bool:
        return bool(self.found)

    def __iter__(self) -> Iterator[str]:
        return iter(self.found)


class DataError(Exception):
    """data/ has problems (DATA-R63); the generator writes nothing."""

    def __init__(self, problems: list[str]) -> None:
        super().__init__(f"{len(problems)} problem(s) in data/")
        self.problems = problems


def fail(prog: str, problems: Iterable[str], undone: str) -> int:
    """Prints every problem (DATA-R63), then their count and what the run didn't do ("wrote nothing"); returns the
    exit code, 1. problems is a Problems or a DataError's list."""
    found = list(problems)
    for problem in found:
        print(f"{prog}: {problem}", file=sys.stderr)
    print(f"{prog}: {len(found)} problem(s); {undone}", file=sys.stderr)
    return 1
