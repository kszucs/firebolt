from memory import ArcPointer, memcpy
from collections.string import StringSlice
from ..buffers import Buffer
from ..dtypes import *


struct StringArray(Array):
    var data: ArrayData
    var bitmap: ArcPointer[Bitmap]
    var offsets: ArcPointer[Buffer]
    var values: ArcPointer[Buffer]
    var capacity: Int

    fn __init__(out self, data: ArrayData) raises:
        if data.dtype != string:
            raise Error("Unexpected dtype")
        elif len(data.buffers) != 2:
            raise Error("StringArray requires exactly two buffers")

        self.data = data
        self.bitmap = data.bitmap
        self.offsets = data.buffers[0]
        self.values = data.buffers[1]
        self.capacity = data.length

    fn __init__(out self, capacity: Int = 0):
        var bitmap = Bitmap.alloc(capacity)
        # TODO(kszucs): initial values capacity should be either 0 or some value received from the user
        var values = Buffer.alloc[DType.uint8](capacity)
        var offsets = Buffer.alloc[DType.uint32](capacity + 1)
        offsets.unsafe_set[DType.uint32](0, 0)

        self.capacity = capacity
        self.bitmap = bitmap^
        self.offsets = offsets^
        self.values = values^
        self.data = ArrayData(
            dtype=string,
            length=0,
            bitmap=self.bitmap,
            buffers=List(self.offsets, self.values),
            children=List[ArcPointer[ArrayData]](),
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

    fn grow(mut self, capacity: Int):
        self.bitmap[].as_buffer()[].grow[DType.bool](capacity)
        self.offsets[].grow[DType.uint32](capacity + 1)
        self.capacity = capacity

    # fn shrink_to_fit(out self):

    fn is_valid(self, index: Int) -> Bool:
        return self.bitmap[].unsafe_get(index)

    fn unsafe_append(mut self, value: String):
        # todo(kszucs): use unsafe set
        var index = self.data.length
        var last_offset = self.offsets[].unsafe_get[DType.uint32](index)
        var next_offset = last_offset + len(value)
        self.data.length += 1
        self.bitmap[].unsafe_set(index, True)
        self.offsets[].unsafe_set[DType.uint32](index + 1, next_offset)
        self.values[].grow[DType.uint8](next_offset)
        var dst_address = self.values[].offset(Int(last_offset))
        var src_address = value.unsafe_ptr()
        memcpy(dst_address, src_address, len(value))

    fn unsafe_get(self, index: UInt) -> StringSlice[__origin_of(self)]:
        var start_offset = self.offsets[].unsafe_get[DType.uint32](index)
        var end_offset = self.offsets[].unsafe_get[DType.uint32](index + 1)
        var address = self.values[].offset(Int(start_offset))
        var length = UInt(Int(end_offset - start_offset))
        return StringSlice[__origin_of(self)](ptr=address, length=length)

    fn unsafe_set(mut self, index: Int, value: String) raises:
        var start_offset = self.offsets[].unsafe_get[DType.int32](index)
        var end_offset = self.offsets[].unsafe_get[DType.int32](index + 1)
        var length = Int(end_offset - start_offset)

        if length != len(value):
            raise Error(
                "String length mismatch, inplace update must have the same"
                " length"
            )

        var dst_address = self.values[].offset(Int(start_offset))
        var src_address = value.unsafe_ptr()
        memcpy(dst_address, src_address, length)
