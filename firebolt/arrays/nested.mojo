from memory import ArcPointer
from ..buffers import Buffer, Bitmap
from ..dtypes import *


struct ListArray(Array):
    var data: ArrayData
    var bitmap: ArcPointer[Bitmap]
    var offsets: ArcPointer[Buffer]
    var values: ArcPointer[ArrayData]
    var capacity: Int

    fn __init__(out self, data: ArrayData) raises:
        if not data.dtype.is_list():
            raise Error("Unexpected dtype")
        elif len(data.buffers) != 1:
            raise Error("ListArray requires exactly one buffer")
        elif len(data.children) != 1:
            raise Error("ListArray requires exactly one child array")

        self.data = data
        self.bitmap = data.bitmap
        self.offsets = data.buffers[0]
        self.values = data.children[0]
        self.capacity = data.length

    fn __init__[T: Array](out self, values: T, capacity: Int = 0):
        var bitmap = Bitmap.alloc(capacity)
        var offsets = Buffer.alloc[DType.uint32](capacity + 1)
        offsets.unsafe_set[DType.uint32](0, 0)

        var values_data = values.as_data()
        var list_dtype = list_(values_data.dtype)

        self.capacity = capacity
        self.bitmap = ArcPointer(bitmap^)
        self.offsets = ArcPointer(offsets^)
        self.values = ArcPointer(values_data^)
        self.data = ArrayData(
            dtype=list_dtype,
            length=0,
            bitmap=self.bitmap,
            buffers=List(self.offsets),
            children=List(self.values),
        )

    fn __moveinit__(out self, deinit existing: Self):
        self.data = existing.data^
        self.bitmap = existing.bitmap^
        self.offsets = existing.offsets^
        self.values = existing.values^
        self.capacity = existing.capacity

    fn __len__(self) -> Int:
        return self.data.length

    fn as_data(self) -> ArrayData:
        return self.data

    fn is_valid(self, index: Int) -> Bool:
        return self.bitmap[].unsafe_get(index)

    fn unsafe_append(mut self, is_valid: Bool):
        self.bitmap[].unsafe_set(self.data.length, is_valid)
        self.offsets[].unsafe_set[DType.uint32](
            self.data.length + 1, self.values[].length
        )
        self.data.length += 1


struct StructArray(Array):
    var data: ArrayData
    var bitmap: ArcPointer[Bitmap]
    var fields: List[Field]
    var capacity: Int

    fn __init__(
        out self,
        var fields: List[Field],
        capacity: Int = 0,
    ):
        var bitmap = Bitmap.alloc(capacity)
        bitmap.unsafe_range_set(0, capacity, True)

        var struct_dtype = struct_(fields)

        self.capacity = capacity
        self.bitmap = ArcPointer(bitmap^)
        self.fields = fields^
        self.data = ArrayData(
            dtype=struct_dtype,
            length=0,
            bitmap=self.bitmap,
            buffers=List[ArcPointer[Buffer]](),
            children=List[ArcPointer[ArrayData]](),
        )

    fn __moveinit__(out self, deinit existing: Self):
        self.data = existing.data^
        self.bitmap = existing.bitmap^
        self.fields = existing.fields^
        self.capacity = existing.capacity

    fn __len__(self) -> Int:
        return self.data.length

    fn as_data(self) -> ArrayData:
        return self.data
