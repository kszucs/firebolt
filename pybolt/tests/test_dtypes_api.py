"""Test the DataType Python api."""

import pybolt as pb


def test_factory_functions() -> None:
    """Test that all DataType factory functions work and return DataType."""
    assert isinstance(pb.null(), pb.DataType)
    assert isinstance(pb.bool_(), pb.DataType)
    assert isinstance(pb.int8(), pb.DataType)
    assert isinstance(pb.int16(), pb.DataType)
    assert isinstance(pb.int32(), pb.DataType)
    assert isinstance(pb.int64(), pb.DataType)
    assert isinstance(pb.uint8(), pb.DataType)
    assert isinstance(pb.uint16(), pb.DataType)
    assert isinstance(pb.uint32(), pb.DataType)
    assert isinstance(pb.uint64(), pb.DataType)
    assert isinstance(pb.float16(), pb.DataType)
    assert isinstance(pb.float32(), pb.DataType)
    assert isinstance(pb.float64(), pb.DataType)
    assert isinstance(pb.string(), pb.DataType)
    assert isinstance(pb.binary(), pb.DataType)
