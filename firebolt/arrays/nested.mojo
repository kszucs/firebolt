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
        self.bitmap = bitmap^
        self.offsets = offsets^
        self.values = values_data^
        self.data = ArrayData(
            dtype=list_dtype,
            length=0,
            bitmap=self.bitmap,
            buffers=List(self.offsets),
            children=List(self.values),
        )

    fn __moveinit__(out self, owned existing: Self):
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
    var bitmap: ArcPointer[Buffer]
    var fields: List[ArcPointer[ArrayData]]
    var capacity: Int

    fn __init__(out self, fields: List[Array], capacity: Int = 0):
        var field_datas = List[ArcPointer[ArrayData]]()
        var field_dtypes = List[DataType]()
        for field in fields:
            var data = field.as_data()
            field_dtypes.append(data.dtype)
            field_datas.append(data^)

        var bitmap = Buffer.alloc[DType.bool](capacity)
        var struct_dtype = struct_(field_dtypes)

        self.capacity = capacity
        self.bitmap = bitmap^
        self.fields = field_datas^
        self.data = ArrayData(
            dtype=struct_dtype,
            length=0,
            bitmap=self.bitmap,
            buffers=List(),
            children=self.fields,
        )

    fn __moveinit__(out self, owned existing: Self):
        self.data = existing.data^
        self.bitmap = existing.bitmap^
        self.fields = existing.fields^
        self.capacity = existing.capacity

    fn __len__(self) -> Int:
        return self.data.length

    fn as_data(self) -> ArrayData:
        return self.data
