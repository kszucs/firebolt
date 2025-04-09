from testing import assert_equal, assert_true, assert_false


from firebolt.arrays import *
from firebolt.dtypes import *


def test_string_builder():
    var a = StringArray()
    assert_equal(len(a), 0)
    assert_equal(a.capacity, 0)

    a.grow(2)
    assert_equal(len(a), 0)
    assert_equal(a.capacity, 2)

    a.unsafe_append("hello")
    a.unsafe_append("world")
    assert_equal(len(a), 2)
    assert_equal(a.capacity, 2)

    var s = a.unsafe_get(0)
    assert_equal(String(s), "hello")
