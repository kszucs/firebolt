from testing import assert_equal, assert_true, assert_false
from python import Python
from firebolt.c_data import *


def test_schema_from_pyarrow():
    var pa = Python.import_module("pyarrow")
    var pyint = pa.field("int_field", pa.int32())
    var pystring = pa.field("string_field", pa.string())
    var pyschema = pa.schema([])
    pyschema = pyschema.append(pyint)
    pyschema = pyschema.append(pystring)

    var c_schema = CArrowSchema.from_pyarrow(pyschema)
    var schema = c_schema.to_dtype()

    assert_equal(schema.fields[0].name, "int_field")
    assert_equal(schema.fields[0].dtype, int32)
    assert_equal(schema.fields[1].name, "string_field")
    assert_equal(schema.fields[1].dtype, string)


def test_primitive_array_from_pyarrow():
    var pa = Python.import_module("pyarrow")
    var pyarr = pa.array(
        [1, 2, 3, 4, 5], mask=[False, False, False, False, True]
    )

    var c_array = CArrowArray.from_pyarrow(pyarr)
    var c_schema = CArrowSchema.from_pyarrow(pyarr.type)

    var dtype = c_schema.to_dtype()
    assert_equal(dtype, int64)
    assert_equal(c_array.length, 5)
    assert_equal(c_array.null_count, 1)
    assert_equal(c_array.offset, 0)
    assert_equal(c_array.n_buffers, 2)
    assert_equal(c_array.n_children, 0)

    var data = c_array.to_array(dtype)
    var array = data.as_int64()
    assert_equal(array.bitmap[].size, 64)
    assert_equal(array.is_valid(0), True)
    assert_equal(array.is_valid(1), True)
    assert_equal(array.is_valid(2), True)
    assert_equal(array.is_valid(3), True)
    assert_equal(array.is_valid(4), False)
    assert_equal(array.unsafe_get(0), 1)
    assert_equal(array.unsafe_get(1), 2)
    assert_equal(array.unsafe_get(2), 3)
    assert_equal(array.unsafe_get(3), 4)
    assert_equal(array.unsafe_get(4), 0)

    array.unsafe_set(0, 10)
    assert_equal(array.unsafe_get(0), 10)
    assert_equal(str(pyarr), "[\n  10,\n  2,\n  3,\n  4,\n  null\n]")


def test_binary_array_from_pyarrow():
    var pa = Python.import_module("pyarrow")

    var pyarr = pa.array(["foo", "bar", "baz"], mask=[False, False, True])

    var c_array = CArrowArray.from_pyarrow(pyarr)
    var c_schema = CArrowSchema.from_pyarrow(pyarr.type)

    var dtype = c_schema.to_dtype()
    assert_equal(dtype, string)

    assert_equal(c_array.length, 3)
    assert_equal(c_array.null_count, 1)
    assert_equal(c_array.offset, 0)
    assert_equal(c_array.n_buffers, 3)
    assert_equal(c_array.n_children, 0)

    var data = c_array.to_array(dtype)
    var array = data.as_string()

    assert_equal(array.bitmap[].size, 64)
    assert_equal(array.is_valid(0), True)
    assert_equal(array.is_valid(1), True)
    assert_equal(array.is_valid(2), False)

    assert_equal(array.unsafe_get(0), "foo")
    assert_equal(array.unsafe_get(1), "bar")
    assert_equal(array.unsafe_get(2), "")

    array.unsafe_set(0, "qux")
    assert_equal(array.unsafe_get(0), "qux")
    assert_equal(str(pyarr), '[\n  "qux",\n  "bar",\n  null\n]')


def test_list_array_from_pyarrow():
    var pa = Python.import_module("pyarrow")

    var pylist1 = PythonObject([1, 2, 3])
    var pylist2 = PythonObject([4, 5])
    var pylist3 = PythonObject([6, 7])
    var pyarr = pa.array([pylist1, pylist2, pylist3], mask=[False, True, False])

    var c_array = CArrowArray.from_pyarrow(pyarr)
    var c_schema = CArrowSchema.from_pyarrow(pyarr.type)

    var dtype = c_schema.to_dtype()
    assert_equal(dtype, list_(int64))

    assert_equal(c_array.length, 3)
    assert_equal(c_array.null_count, 1)
    assert_equal(c_array.offset, 0)
    assert_equal(c_array.n_buffers, 2)
    assert_equal(c_array.n_children, 1)

    var data = c_array.to_array(dtype)
    var array = data.as_list()

    assert_equal(array.bitmap[].size, 64)
    assert_equal(array.is_valid(0), True)
    assert_equal(array.is_valid(1), False)
    assert_equal(array.is_valid(2), True)

    var values = array.values[].as_int64()
    assert_equal(values.unsafe_get(0), 1)
    assert_equal(values.unsafe_get(1), 2)
    values.unsafe_set(0, 10)
    values.unsafe_set(2, 30)

    assert_equal(
        str(pyarr),
        (
            "[\n  [\n    10,\n    2,\n    30\n  ],\n  null,\n  [\n    6,\n   "
            " 7\n  ]\n]"
        ),
    )


# def test_schema_to_pyarrow():
#     var pa = Python.import_module("pyarrow")

#     var struct_type = struct_(
#         Field("int_field", int32),
#         Field("string_field", string),
#     )

#     try:
#         # mojo->python direction is not working yet
#         var c_schema = CArrowSchema.from_dtype(int32)
#     except Error:
#         pass
