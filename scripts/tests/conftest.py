"""Immutable generated outputs for the unchanged repository snapshot."""

from collections.abc import Mapping
from pathlib import Path
from types import MappingProxyType

import pytest

from pagle_data.generate import generate


@pytest.fixture(scope="session")
def repo_outputs() -> Mapping[str, str]:
    return MappingProxyType(generate(Path(__file__).resolve().parents[2]))
