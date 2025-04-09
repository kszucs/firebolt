from testing import assert_equal, assert_true, assert_false


from firebolt.arrays import *
from firebolt.dtypes import *
from firebolt.arrays.tests.utils import as_bool_array_scalar


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
