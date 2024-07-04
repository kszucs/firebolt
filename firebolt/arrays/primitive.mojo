from ..buffers import Buffer
from ..dtypes import *


struct PrimitiveArray[T: DataType](Array):
    alias dtype = T
    alias scalar = Scalar[T.native]
    var data: ArrayData
    var bitmap: Arc[Buffer]
    var buffer: Arc[Buffer]
    var capacity: Int

    fn __init__(inout self, data: ArrayData) raises:
        # TODO(kszucs): put a dtype constraint here
        if data.dtype != T:
            raise Error("Unexpected dtype")
        elif len(data.buffers) != 1:
            raise Error("PrimitiveArray requires exactly one buffer")

        self.data = data
        self.bitmap = data.bitmap
        self.buffer = data.buffers[0]
        self.capacity = data.length

    fn __init__(inout self, capacity: Int = 0):
        self.capacity = capacity
        self.bitmap = Buffer.alloc[DType.bool](capacity)
        self.buffer = Buffer.alloc[T.native](capacity)
        self.data = ArrayData(
            dtype=T,
            length=0,
            bitmap=self.bitmap,
            buffers=List(self.buffer),
            children=List[Arc[ArrayData]](),
        )

    fn __moveinit__(inout self, owned existing: Self):
        self.data = existing.data^
        self.bitmap = existing.bitmap^
        self.buffer = existing.buffer^
        self.capacity = existing.capacity

    fn as_data(self) -> ArrayData:
        return self.data

    fn grow(inout self, capacity: Int):
        self.bitmap[].grow[DType.bool](capacity)
        self.buffer[].grow[T.native](capacity)
        self.capacity = capacity

    @always_inline
    fn __len__(self) -> Int:
        return self.data.length

    @always_inline
    fn is_valid(self, index: Int) -> Bool:
        return self.bitmap[].unsafe_get[DType.bool](index)

    @always_inline
    fn unsafe_get(self, index: Int) -> Self.scalar:
        return self.buffer[].unsafe_get[T.native](index)

    @always_inline
    fn unsafe_set(inout self, index: Int, value: Self.scalar):
        self.bitmap[].unsafe_set[DType.bool](index, True)
        self.buffer[].unsafe_set[T.native](index, value)

    @always_inline
    fn unsafe_append(inout self, value: Self.scalar):
        self.unsafe_set(self.data.length, value)
        self.data.length += 1

    fn append(inout self, value: Self.scalar):
        if self.data.length >= self.capacity:
            self.grow(self.capacity * 2)
        self.unsafe_append(value)

    # fn append(inout self, value: Optional[Self.scalar]):

    fn extend(inout self, values: List[Bool]):
        if self.length + len(values) >= self.capacity:
            self.grow(self.capacity + len(values))
        for value in values:
            self.unsafe_append(value)


alias BoolArray = PrimitiveArray[bool_]
alias Int8Array = PrimitiveArray[int8]
alias Int16Array = PrimitiveArray[int16]
alias Int32Array = PrimitiveArray[int32]
alias Int64Array = PrimitiveArray[int64]
alias UInt8Array = PrimitiveArray[uint8]
alias UInt16Array = PrimitiveArray[uint16]
alias UInt32Array = PrimitiveArray[uint32]
alias UInt64Array = PrimitiveArray[uint64]
