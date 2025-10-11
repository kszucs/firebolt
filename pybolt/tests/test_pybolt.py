"""Test the python extension of FireBolt."""

# The mojo.importer will automatically compile the mojo code.
# For a more flexible, Bazel based, approach see
#    https://github.com/winding-lines/herringbone
import mojo.importer  # NOQA

import sys
from os.path import dirname

sys.path.insert(0, dirname(dirname(__file__)))
import pybolt  # NOQA


def test_to_pydict() -> None:
    assert pybolt.to_pydict({}) == {}
