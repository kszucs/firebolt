from testing import assert_equal, assert_true, assert_false


from firebolt.arrays import *
from firebolt.dtypes import *
from firebolt.test_fixtures.bool_array import as_bool_array_scalar


def test_list_int_array():
    var ints = Int64Array()
    var lists = ListArray(ints)
    assert_equal(lists.data.dtype, list_(int64))

    ints.append(1)
    ints.append(2)
    ints.append(3)
    lists.unsafe_append(True)
    assert_equal(len(lists), 1)

    var data = lists.as_data()
    assert_equal(data.length, 1)

    var arr = data.as_list()
    assert_equal(len(arr), 1)


def test_list_bool_array():
    var bools = BoolArray()
    var lists = ListArray(bools)

    bools.append(as_bool_array_scalar(True))
    bools.append(as_bool_array_scalar(False))
    bools.append(as_bool_array_scalar(True))
    lists.unsafe_append(True)
    assert_equal(len(lists), 1)


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
