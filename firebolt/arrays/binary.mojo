from ..buffers import Buffer
from ..dtypes import *


struct StringArray(Array):
    var data: ArrayData
    var bitmap: Arc[Buffer]
    var offsets: Arc[Buffer]
    var values: Arc[Buffer]
    var capacity: Int

    fn __init__(inout self, data: ArrayData) raises:
        if data.dtype != string:
            raise Error("Unexpected dtype")
        elif len(data.buffers) != 2:
            raise Error("StringArray requires exactly two buffers")

        self.data = data
        self.bitmap = data.bitmap
        self.offsets = data.buffers[0]
        self.values = data.buffers[1]
        self.capacity = data.length

    fn __init__(inout self, capacity: Int = 0):
        var bitmap = Buffer.alloc[DType.bool](capacity)
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
            children=List[Arc[ArrayData]](),
        )

    fn __moveinit__(inout self, owned existing: Self):
        self.data = existing.data^
        self.bitmap = existing.bitmap^
        self.offsets = existing.offsets^
        self.values = existing.values^
        self.capacity = existing.capacity

    fn __len__(self) -> Int:
        return self.data.length

    fn as_data(self) -> ArrayData:
        return self.data

    fn grow(inout self, capacity: Int):
        self.bitmap[].grow[DType.bool](capacity)
        self.offsets[].grow[DType.uint32](capacity + 1)
        self.capacity = capacity

    # fn shrink_to_fit(inout self):

    fn is_valid(self, index: Int) -> Bool:
        return self.bitmap[].unsafe_get[DType.bool](index)

    fn unsafe_append(inout self, value: String):
        # todo(kszucs): use unsafe set
        var index = self.data.length
        var last_offset = self.offsets[].unsafe_get[DType.uint32](index)
        var next_offset = last_offset + len(value)
        self.data.length += 1
        self.bitmap[].unsafe_set[DType.bool](index, True)
        self.offsets[].unsafe_set[DType.uint32](index + 1, next_offset)
        self.values[].grow[DType.uint8](next_offset)
        var dst_address = self.values[].offset(int(last_offset))
        var src_address = value.unsafe_ptr()
        memcpy(dst_address, src_address, len(value))

    fn unsafe_get(self, index: Int) -> String:
        var start_offset = self.offsets[].unsafe_get[DType.int32](index)
        var end_offset = self.offsets[].unsafe_get[DType.int32](index + 1)
        var address = self.values[].offset(int(start_offset))
        var length = int(end_offset - start_offset)
        return StringRef(address, length)

    fn unsafe_set(inout self, index: Int, value: String) raises:
        var start_offset = self.offsets[].unsafe_get[DType.int32](index)
        var end_offset = self.offsets[].unsafe_get[DType.int32](index + 1)
        var length = int(end_offset - start_offset)

        if length != len(value):
            raise Error(
                "String length mismatch, inplace update must have the same"
                " length"
            )

        var dst_address = self.values[].offset(int(start_offset))
        var src_address = value.unsafe_ptr()
        memcpy(dst_address, src_address, length)
