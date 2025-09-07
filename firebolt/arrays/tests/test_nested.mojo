from testing import assert_equal, assert_true, assert_false


from firebolt.arrays import *
from firebolt.dtypes import *
from firebolt.test_fixtures.bool_array import as_bool_array_scalar


def test_list_int_array():
    var ints = Int64Array(capacity=3)
    ints.append(1)
    ints.append(2)
    ints.append(3)
    var lists = ListArray(ints^)
    assert_equal(lists.data.dtype, list_(int64))

    assert_equal(len(lists), 1)

    var data = lists.as_data()
    assert_equal(data.length, 1)

    var arr = data.as_list()
    assert_equal(len(arr), 1)

    var first_value = lists.unsafe_get(0)
    assert_equal(first_value.__str__().strip(), "1 2 3")


def test_list_bool_array():
    var bools = BoolArray()

    bools.append(as_bool_array_scalar(True))
    bools.append(as_bool_array_scalar(False))
    bools.append(as_bool_array_scalar(True))

    var lists = ListArray(bools^)
    assert_equal(len(lists), 1)
    var first_value = lists.unsafe_get(0)

    fn get(index: Int) -> Bool:
        return first_value.buffers[0][].unsafe_get[DType.bool](index)

    assert_equal(get(0), True)
    assert_equal(get(1), False)
    assert_equal(get(2), True)


def test_list_str():
    var strings = StringArray()
    strings.unsafe_append("hello")
    strings.unsafe_append("world")

    var lists = ListArray(strings^)
    var first_value = StringArray(lists.unsafe_get(0))

    assert_equal(first_value.unsafe_get(0), "hello")
    assert_equal(first_value.unsafe_get(1), "world")


def test_struct_array():
    var fields = List[Field](
        Field("id", int64),
        Field("name", string),
        Field("active", bool_),
    )

    var struct_arr = StructArray(fields, capacity=10)
    assert_equal(len(struct_arr), 0)
    assert_equal(struct_arr.capacity, 10)

    var data = struct_arr.as_data()
    assert_equal(data.length, 0)
    assert_true(data.dtype.is_struct())
    assert_equal(len(data.dtype.fields), 3)
    assert_equal(data.dtype.fields[0].name, "id")
    assert_equal(data.dtype.fields[1].name, "name")
    assert_equal(data.dtype.fields[2].name, "active")


def test_list_array_str_repr():
    var ints = Int64Array()
    var lists = ListArray(ints^)

    var str_repr = lists.__str__()
    var repr_repr = lists.__repr__()

    assert_equal(str_repr, "ListArray(length=1)")
    assert_equal(repr_repr, "ListArray(length=1)")
    assert_equal(str_repr, repr_repr)


def test_struct_array_str_repr():
    var fields = List[Field](
        Field("id", int64),
        Field("name", string),
    )

    var struct_arr = StructArray(fields, capacity=5)

    var str_repr = struct_arr.__str__()
    var repr_repr = struct_arr.__repr__()

    assert_equal(str_repr, "StructArray(length=0)")
    assert_equal(repr_repr, "StructArray(length=0)")
    assert_equal(str_repr, repr_repr)
