from testing import assert_equal, assert_true, assert_false


from firebolt.arrays import *
from firebolt.test_fixtures.bool_array import as_bool_array_scalar
from firebolt.test_fixtures.arrays import build_array_data, assert_bitmap_set


def test_boolean_array():
    var a = BoolArray()
    assert_equal(len(a), 0)
    assert_equal(a.capacity, 0)

    a.grow(3)
    assert_equal(len(a), 0)
    assert_equal(a.capacity, 3)

    a.append(as_bool_array_scalar(True))
    a.append(as_bool_array_scalar(False))
    a.append(as_bool_array_scalar(True))
    assert_equal(len(a), 3)
    assert_equal(a.capacity, 3)

    a.append(as_bool_array_scalar(True))
    assert_equal(len(a), 4)
    assert_equal(a.capacity, 6)
    assert_true(a.is_valid(0))
    assert_true(a.is_valid(1))
    assert_true(a.is_valid(2))
    assert_true(a.is_valid(3))

    var d = a.as_data()
    assert_equal(d.length, 4)

    var b = d.as_primitive[bool_]()


def test_e():
    var a = Int8Array()
    assert_equal(len(a), 0)
    assert_equal(a.capacity, 0)
    a.unsafe_append(1)
    a.unsafe_append(2)
    a.unsafe_append(3)
    assert_equal(len(a), 3)


def test_array_from_ints():
    var g = array[int8](1, 2)
    assert_equal(len(g), 2)
    assert_equal(g.dtype, int8)
    assert_equal(g.unsafe_get(0), 1)
    assert_equal(g.unsafe_get(1), 2)


def test_drop_null() -> None:
    """Test the drop null function."""
    var array_data = build_array_data(10, 5)

    var primitive_array = PrimitiveArray[uint8](array_data^)
    #
    # Check the setup.
    assert_equal(primitive_array.null_count(), 5)
    assert_bitmap_set(
        primitive_array.bitmap[], List[Int](1, 3, 5, 7, 9), "check setup"
    )

    primitive_array.drop_nulls[DType.uint8]()
    assert_equal(primitive_array.unsafe_get(0), 1)
    assert_equal(primitive_array.unsafe_get(1), 3)
    assert_equal(primitive_array.null_count(), 0)
    assert_bitmap_set(
        primitive_array.bitmap[], List[Int](0, 1, 2, 3, 4), "after drop"
    )
