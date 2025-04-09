from testing import assert_equal, assert_true, assert_false
from sys.info import alignof

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
    assert_equal(b.size, 64)
    b.grow(20)
    assert_equal(b.size, 64)
    b.grow(80)
    assert_equal(b.size, 128)


def test_buffer():
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


def test_bitmap():
    var b = Buffer.alloc[DType.bool](10)
    assert_equal(b.size, 64)
    assert_equal(b.length[DType.bool](), 64 * 8)

    b.unsafe_set(0, True)
    assert_true(b.unsafe_get[DType.bool](0))
    assert_false(b.unsafe_get[DType.bool](1))
    b.unsafe_set(1, True)
    assert_true(b.unsafe_get[DType.bool](1))
