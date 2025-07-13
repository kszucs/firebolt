from testing import assert_equal
from firebolt.arrays.base import ChunkedArray, ArrayData
from firebolt.buffers import Buffer, Bitmap
from firebolt.dtypes import int8
from memory import ArcPointer


def test_chunked_array():
    var bitmap = ArcPointer(Bitmap.alloc(1))
    var buffers = List[ArcPointer[Buffer]]()
    buffers.append(ArcPointer(Buffer.alloc[DType.uint8](1)))
    var array_data = ArrayData(
        dtype=int8,
        length=0,
        bitmap=bitmap,
        buffers=buffers,
        children=List[ArcPointer[ArrayData]](),
    )
    var arrays = List[ArrayData]()
    arrays.append(array_data^)
    var chunked_array = ChunkedArray(int8, arrays)
    assert_equal(chunked_array.length, 0)
