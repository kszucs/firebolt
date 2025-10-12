"""Test the python extension of FireBolt."""

import pybolt


def test_to_pydict() -> None:
    assert pybolt.to_pydict({}) == {}
