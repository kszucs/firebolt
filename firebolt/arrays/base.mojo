from .primitive import *


trait Array(Movable, Sized):
    fn as_data(self) -> ArrayData:
        ...


@value
struct ArrayData(Movable):
    var dtype: DataType
    var length: Int
    var bitmap: Arc[Buffer]
    var buffers: List[Arc[Buffer]]
    var children: List[Arc[ArrayData]]

    fn is_valid(self, index: Int) -> Bool:
        return self.bitmap[].unsafe_get[DType.bool](index)

    fn as_primitive[T: DataType](self) raises -> PrimitiveArray[T]:
        return PrimitiveArray[T](self)

    fn as_int8(self) raises -> Int8Array:
        return Int8Array(self)

    fn as_int16(self) raises -> Int16Array:
        return Int16Array(self)

    fn as_int32(self) raises -> Int32Array:
        return Int32Array(self)

    fn as_int64(self) raises -> Int64Array:
        return Int64Array(self)

    fn as_uint8(self) raises -> UInt8Array:
        return UInt8Array(self)

    fn as_uint16(self) raises -> UInt16Array:
        return UInt16Array(self)

    fn as_uint32(self) raises -> UInt32Array:
        return UInt32Array(self)

    fn as_uint64(self) raises -> UInt64Array:
        return UInt64Array(self)

    fn as_float32(self) raises -> Float32Array:
        return Float32Array(self)

    fn as_float64(self) raises -> Float64Array:
        return Float64Array(self)

    fn as_string(self) raises -> StringArray:
        return StringArray(self)

    fn as_list(self) raises -> ListArray:
        return ListArray(self)


struct ChunkedArray:
    var dtype: DataType
    var length: Int
    var chunks: List[ArrayData]

    fn __init__(inout self, dtype: DataType, chunks: List[ArrayData]):
        self.dtype = dtype
        self.chunks = chunks
        self.length = 0
        for chunk in chunks:
            self.length += chunk.length
