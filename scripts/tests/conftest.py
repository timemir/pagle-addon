"""Immutable generated outputs for the unchanged repository snapshot."""

from collections.abc import Mapping
from pathlib import Path
from types import MappingProxyType

import pytest

from pagle_data.generate import generate


@pytest.fixture(autouse=True)
def no_base_branch(monkeypatch: pytest.MonkeyPatch) -> None:
    """A test does not inherit the pull request's base branch from the CI job that runs it (DATA-R114's coverage rule)."""
    monkeypatch.delenv("GITHUB_BASE_REF", raising=False)


@pytest.fixture(scope="session")
def repo_outputs() -> Mapping[str, str]:
    return MappingProxyType(generate(Path(__file__).resolve().parents[2]))
