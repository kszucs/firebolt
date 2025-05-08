"""Test the chunked array implementation."""

from testing import assert_equal
from firebolt.arrays.base import ArrayData
from firebolt.buffers import Buffer, Bitmap
from firebolt.arrays.chunked_array import ChunkedArray
from firebolt.dtypes import int8
from memory import ArcPointer
from firebolt.test_fixtures.arrays import build_array_data, assert_bitmap_set


def test_chunked_array():
    var first_array_data = build_array_data(1, 0)
    var arrays = List[ArrayData]()
    arrays.append(first_array_data^)

    var second_array_data = build_array_data(2, 0)
    arrays.append(second_array_data^)

    var chunked_array = ChunkedArray(int8, arrays)
    assert_equal(chunked_array.length, 3)

    assert_equal(chunked_array.chunk(0).length, 1)
    assert_equal(chunked_array.chunk(1).length, 2)


def test_combine_chunked_array():
    var first_array_data = build_array_data(1, 0)
    var arrays = List[ArrayData]()
    arrays.append(first_array_data^)

    var second_array_data = build_array_data(2, 0)
    arrays.append(second_array_data^)

    var chunked_array = ChunkedArray(int8, arrays)
    assert_equal(chunked_array.length, 3)

    var combined_array = chunked_array.combine_chunks()
    assert_equal(combined_array.length, 3)


def test_drop_null():
    var chunked_array = ChunkedArray(int8, List(build_array_data(20, 10)))
    var bitmap = chunked_array.chunks[0].bitmap
    assert_equal(chunked_array.null_count(), 10)
    chunked_array.drop_nulls[DType.uint8]()
    assert_equal(chunked_array.null_count(), 0)
    assert_equal(len(chunked_array.chunks), 1)
    bitmap = chunked_array.chunks[0].bitmap
    assert_bitmap_set(
        bitmap[], List[Int](0, 1, 2, 3, 4, 5, 6, 7, 8, 9), "after drop_nulls"
    )
