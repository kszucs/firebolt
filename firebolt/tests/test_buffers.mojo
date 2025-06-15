from testing import assert_equal, assert_true, assert_false
from sys.info import alignof
from firebolt.test_fixtures.arrays import assert_bitmap_set

from firebolt.buffers import *


def is_aligned[T: AnyType](ptr: UnsafePointer[T], alignment: Int) -> Bool:
    return (Int(ptr) % alignment) == 0


def test_buffer_init():
    var b = Buffer.alloc(10)
    assert_equal(b.size, 64)
    assert_true(is_aligned(b.ptr, 64))

    var b1 = Buffer.alloc[DType.bool](10)
    assert_equal(b1.size, 64)
    assert_true(is_aligned(b1.ptr, 64))

    var b2 = Buffer.alloc[DType.bool](64 * 8 + 1)
    assert_equal(b2.size, 128)
    assert_true(is_aligned(b2.ptr, 64))


def test_buffer_grow():
    var b = Buffer.alloc(10)
    b.unsafe_set(0, 111)
    assert_equal(b.size, 64)
    b.grow(20)
    assert_equal(b.size, 64)
    assert_equal(b.unsafe_get(0), 111)
    b.grow(80)
    assert_equal(b.size, 128)
    assert_equal(b.unsafe_get(0), 111)


def test_buffer_set_get():
    var buf = Buffer.alloc(10)
    assert_equal(buf.size, 64)

    buf.unsafe_set(0, 42)
    buf.unsafe_set(1, 43)
    buf.unsafe_set(2, 44)
    assert_equal(buf.unsafe_get(0), 42)
    assert_equal(buf.unsafe_get(1), 43)
    assert_equal(buf.unsafe_get(2), 44)

    assert_equal(buf.size, 64)
    assert_equal(
        buf.length[DType.uint16](), 32
    )  # 64 bytes / 2 bytes per element
    # reinterpreting the underlying bits as uint16
    assert_equal(buf.unsafe_get[DType.uint16](0), 42 + (43 << 8))
    assert_equal(buf.unsafe_get[DType.uint16](1), 44)


def test_buffer_swap():
    var one = Buffer.alloc(10)
    one.unsafe_set(0, 111)
    var two = Buffer.alloc(10)
    two.unsafe_set(0, 222)

    one.swap(two)

    assert_equal(one.unsafe_get(0), 222)
    assert_equal(two.unsafe_get(0), 111)


def test_bitmap():
    var b = Bitmap.alloc(10)
    assert_equal(b.size(), 64)
    assert_equal(b.length(), 64 * 8)
    assert_equal(b.bit_count(), 0)

    assert_false(b.unsafe_get(0))
    b.unsafe_set(0, True)
    assert_true(b.unsafe_get(0))
    assert_equal(b.bit_count(), 1)
    assert_false(b.unsafe_get(1))
    b.unsafe_set(1, True)
    assert_true(b.unsafe_get(1))
    assert_equal(b.bit_count(), 2)


def test_count_leading_zeros():
    var b = Bitmap.alloc(10)
    var expected_bits = b.length()
    assert_equal(b.count_leading_zeros(), expected_bits)
    assert_equal(b.count_leading_zeros(10), expected_bits - 10)

    b.unsafe_set(0, True)
    assert_equal(b.count_leading_zeros(), 0)
    assert_equal(b.count_leading_zeros(1), expected_bits - 1)
    b.unsafe_set(0, False)

    var to_test = [0, 1, 7, 8, 10, 16, 31]
    for i in range(len(to_test)):
        bit_position = to_test[i]
        b.unsafe_set(bit_position, True)
        assert_equal(b.count_leading_zeros(), bit_position)
        if bit_position > 4:
            # Count with start position.
            assert_equal(b.count_leading_bits(4), bit_position - 4)
        b.unsafe_set(bit_position, False)


def test_count_leading_ones():
    var b = Bitmap.alloc(10)
    assert_equal(b.count_leading_ones(), 0)
    b.unsafe_set(0, True)
    assert_equal(b.count_leading_ones(), 1)
    assert_equal(b.count_leading_ones(1), 0)

    b.unsafe_set(1, True)
    assert_equal(b.count_leading_ones(), 2)
    assert_equal(b.count_leading_ones(1), 1)


def _reset(mut bitmap: Bitmap):
    bitmap.unsafe_range_set(0, bitmap.length(), False)
    assert_bitmap_set(bitmap, [], "after _reset")


def test_unsafe_range_set():
    var bitmap = Bitmap.alloc(16)

    bitmap.unsafe_range_set(0, 0, True)
    assert_bitmap_set(bitmap, [], "range 0")

    var to_test = [0, 1, 7, 8, 15]
    for pos in range(len(to_test)):
        _reset(bitmap)
        var start_bit = to_test[pos]
        bitmap.unsafe_range_set(start_bit, 1, True)
        assert_bitmap_set(bitmap, List(start_bit), "range  1")
        if to_test[pos] < bitmap.length() - 1:
            _reset(bitmap)
            bitmap.unsafe_range_set(start_bit, 2, True)
            assert_bitmap_set(bitmap, List(start_bit, start_bit + 1), "range 2")


def test_partial_byte_set():
    var bitmap = Bitmap.alloc(16)

    bitmap.unsafe_range_set(0, 0, True)
    assert_bitmap_set(bitmap, [], "range 0")

    # Set one bit to True.
    bitmap.partial_byte_set(0, 0, 1, True)
    assert_bitmap_set(bitmap, [0], "set bit 0")

    # Set one bit to False.
    bitmap.partial_byte_set(0, 0, 1, False)
    assert_bitmap_set(bitmap, [], "reset bit 0")

    # Set multiple bits to True.
    bitmap.partial_byte_set(1, 2, 5, True)
    assert_bitmap_set(bitmap, [10, 11, 12], "set multiple bits")

    # Set multiple bits to False.
    bitmap.partial_byte_set(1, 3, 5, False)
    assert_bitmap_set(bitmap, [10], "reset multiple bits")


def test_expand_bitmap() -> None:
    var bitmap = Bitmap.alloc(6)
    bitmap.unsafe_set(0, True)
    bitmap.unsafe_set(5, True)
    assert_bitmap_set(bitmap, [0, 5], "initial setup")

    # Create a new bitmap with 2 bits
    var new_bitmap = Bitmap.alloc(2)
    new_bitmap.unsafe_set(0, True)

    # Expand the bitmap
    bitmap.extend(new_bitmap, 6, 2)
    assert_bitmap_set(bitmap, [0, 5, 6], "after expand")
