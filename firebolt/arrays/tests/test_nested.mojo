from testing import assert_equal, assert_true, assert_false


from firebolt.arrays import *
from firebolt.dtypes import *
from firebolt.test_fixtures.bool_array import as_bool_array_scalar


fn build_list_of_list[data_type: DataType]() raises -> ListArray:
    """Build a test ListArray.

    See: https://elferherrera.github.io/arrow_guide/arrays_nested.html
    """

    # Define all the values.
    var bitmap = ArcPointer(Bitmap.alloc(10))
    bitmap[].unsafe_range_set(0, 10, True)
    var buffer = ArcPointer(Buffer.alloc[data_type.native](10))
    for i in range(10):
        buffer[].unsafe_set[data_type.native](i, i + 1)

    var value_data = ArrayData(
        dtype=materialize[data_type](),
        length=10,
        bitmap=bitmap,
        buffers=List(buffer),
        children=List[ArcPointer[ArrayData]](),
        offset=0,
    )

    # Define the PrimitiveArrays.
    var value_offset = ArcPointer(
        Buffer.from_values[DType.int32](0, 2, 4, 7, 7, 8, 10)
    )

    var list_bitmap = ArcPointer(Bitmap.alloc(6))
    list_bitmap[].unsafe_range_set(0, 6, True)
    list_bitmap[].unsafe_set(3, False)
    var list_data = ArrayData(
        dtype=list_(materialize[data_type]()),
        length=6,
        buffers=List(value_offset),
        children=List(ArcPointer(value_data^)),
        bitmap=list_bitmap,
        offset=0,
    )

    # Now define the master array data.
    var top_offsets = Buffer.from_values[DType.int32](0, 2, 5, 6)
    var top_bitmap = ArcPointer(Bitmap.alloc(4))
    top_bitmap[].unsafe_range_set(0, 4, True)
    return ListArray(
        ArrayData(
            dtype=list_(list_(materialize[data_type]())),
            length=4,
            buffers=List(ArcPointer(top_offsets^)),
            children=List(ArcPointer(list_data^)),
            bitmap=top_bitmap,
            offset=0,
        )
    )


def test_list_int_array():
    var ints = Int64Array(
        ArrayData.from_buffer[int64](
            Buffer.from_values[DType.int64](1, 2, 3), 3
        )
    )
    var lists = ListArray(ints^)
    assert_equal(lists.data.dtype, list_(materialize[int64]()))

    var first_value = lists.unsafe_get(0)
    assert_equal(first_value.__str__().strip(), "1 2 3")

    assert_equal(len(lists), 1)

    var data = lists^.take_data()
    assert_equal(data.length, 1)

    var arr = data^.as_list()
    assert_equal(len(arr), 1)


def test_list_bool_array():
    var bools = BoolArray()

    bools.append(as_bool_array_scalar(True))
    bools.append(as_bool_array_scalar(False))
    bools.append(as_bool_array_scalar(True))

    var lists = ListArray(bools^)
    assert_equal(len(lists), 1)
    var first_value = lists.unsafe_get(0)
    var buffer = first_value.buffers[0]

    fn get(index: Int) -> Bool:
        return buffer[].unsafe_get[DType.bool](index)

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


def test_list_of_list():
    list2 = build_list_of_list[int64]()
    top = ListArray(list2.unsafe_get(0))
    middle_0 = top.unsafe_get(0)
    bottom = Int64Array(middle_0^)
    assert_equal(bottom.unsafe_get(1), 2)
    assert_equal(bottom.unsafe_get(0), 1)
    middle_1 = top.unsafe_get(1)
    bottom = Int64Array(middle_1^)
    assert_equal(bottom.unsafe_get(0), 3)
    assert_equal(bottom.unsafe_get(1), 4)


def test_struct_array():
    var fields = List[Field](
        Field("id", materialize[int64]()),
        Field("name", materialize[string]()),
        Field("active", materialize[bool_]()),
    )

    var struct_arr = StructArray(fields^, capacity=10)
    assert_equal(len(struct_arr), 0)
    assert_equal(struct_arr.capacity, 10)

    var data = struct_arr^.take_data()
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
        Field("id", materialize[int64]()),
        Field("name", materialize[string]()),
    )

    var struct_arr = StructArray(fields^, capacity=5)

    var str_repr = struct_arr.__str__()
    var repr_repr = struct_arr.__repr__()

    assert_equal(str_repr, "StructArray(length=0)")
    assert_equal(repr_repr, "StructArray(length=0)")
    assert_equal(str_repr, repr_repr)


fn main() raises:
    test_list_of_list()
