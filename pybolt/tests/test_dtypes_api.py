"""Test the DataType Python api."""

import pybolt


def test_factory_functions() -> None:
    """Test that all DataType factory functions work and return correct types."""
    assert isinstance(pybolt.null(), pybolt.DataType)
    assert isinstance(pybolt.bool_(), pybolt.DataType)
    assert isinstance(pybolt.int8(), pybolt.DataType)
    assert isinstance(pybolt.int16(), pybolt.DataType)
    assert isinstance(pybolt.int32(), pybolt.DataType)
    assert isinstance(pybolt.int64(), pybolt.DataType)
    assert isinstance(pybolt.uint8(), pybolt.DataType)
    assert isinstance(pybolt.uint16(), pybolt.DataType)
    assert isinstance(pybolt.uint32(), pybolt.DataType)
    assert isinstance(pybolt.uint64(), pybolt.DataType)
    assert isinstance(pybolt.float16(), pybolt.DataType)
    assert isinstance(pybolt.float32(), pybolt.DataType)
    assert isinstance(pybolt.float64(), pybolt.DataType)
    assert isinstance(pybolt.string(), pybolt.DataType)
    assert isinstance(pybolt.binary(), pybolt.DataType)
