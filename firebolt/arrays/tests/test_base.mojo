"""Test the base module."""
from testing import assert_true, assert_false, assert_equal
from memory import UnsafePointer, ArcPointer
from firebolt.arrays.base import ArrayData
from firebolt.buffers import Buffer, Bitmap
from firebolt.dtypes import DType, int8
from firebolt.test_fixtures.arrays import build_array_data, assert_bitmap_set


def test_drop_null() -> None:
    """Test the drop null function."""
    var array = build_array_data(10, 5)

    # Check the setup.
    assert_equal(array.null_count(), 5)
    assert_bitmap_set(array.bitmap[], List[Int](1, 3, 5, 7, 9), "check setup")

    array.drop_nulls[DType.uint8]()
    var first_buffer = array.buffers[0]
    assert_equal(first_buffer[].unsafe_get(0), 1)
    assert_equal(first_buffer[].unsafe_get(1), 3)
    assert_equal(array.null_count(), 0)
    assert_bitmap_set(array.bitmap[], List[Int](0, 1, 2, 3, 4), "after drop")
