import importlib

import pytest

import vbtso

SUBPACKAGES = ["data", "models", "tracking", "control", "api"]


def test_version_is_set():
    assert vbtso.__version__


@pytest.mark.parametrize("name", SUBPACKAGES)
def test_subpackage_imports(name):
    assert importlib.import_module(f"vbtso.{name}")
