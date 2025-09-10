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

    assert_equal(String(a.unsafe_get(0)), "hello")
    assert_equal(String(a.unsafe_get(1)), "world")

    assert_equal(
        a.__str__().strip(),
        'StringArray( length=2, data= ["hello", "world",  ])',
    )
