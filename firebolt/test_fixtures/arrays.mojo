from firebolt.arrays import BoolArray, ArrayData
from memory import ArcPointer
from firebolt.buffers import Buffer, Bitmap
from firebolt.dtypes import uint8
from testing import assert_equal
from builtin._location import __call_location


fn as_bool_array_scalar(value: Bool) -> BoolArray.scalar:
    """Bool conversion function."""
    return BoolArray.scalar(Scalar[DType.bool](value))


fn bool_array(*values: Bool) -> BoolArray:
    var a = BoolArray(len(values))
    for value in values:
        a.unsafe_append(as_bool_array_scalar(value))
    return a^


def build_array_data(length: Int, nulls: Int) -> ArrayData:
    """Builds an ArrayData object with nulls.

    Args:
        length: The length of the array.
        nulls: The number of nulls to set.
    """
    var bitmap = Bitmap.alloc(length)
    var buffer = Buffer.alloc[DType.uint8](length)
    for i in range(length):
        buffer.unsafe_set(i, i % 256)
        # Check to see if the current index should be valid or null.
        var is_valid = True
        if nulls > 0:
            if i % (Int(length / nulls)) == 0:
                is_valid = False
        bitmap.unsafe_set(i, is_valid)

    var buffers = List(ArcPointer(buffer^))
    return ArrayData(
        dtype=materialize[uint8](),
        length=length,
        bitmap=ArcPointer(bitmap^),
        buffers=buffers^,
        children=List[ArcPointer[ArrayData]](),
        offset=0,
    )


@always_inline
def assert_bitmap_set(
    bitmap: Bitmap, expected_true_pos: List[Int], message: StringLiteral
) -> None:
    var list_pos = 0
    for i in range(bitmap.length()):
        var expected_value = False
        if list_pos < len(expected_true_pos):
            if expected_true_pos[list_pos] == i:
                expected_value = True
                list_pos += 1
        var current_value = bitmap.unsafe_get(i)
        assert_equal(
            current_value,
            expected_value,
            String(
                "{}: Bitmap index {} is {}, expected {} as per list position {}"
            ).format(message, i, current_value, expected_value, list_pos),
            location=__call_location(),
        )
