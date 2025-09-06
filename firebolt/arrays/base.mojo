from .primitive import *
from ..buffers import Buffer, Bitmap
from sys.info import sizeof


trait Array(Movable, Representable, Sized, Stringable, Writable):
    fn as_data(self) -> ArrayData:
        ...


@fieldwise_init
struct ArrayData(Copyable, Movable, Representable, Stringable, Writable):
    """ArrayData is the lower level abstraction directly usable by the library consumer.

    Equivalent with https://github.com/apache/arrow/blob/7184439dea96cd285e6de00e07c5114e4919a465/cpp/src/arrow/array/data.h#L62-L84.
    """

    var dtype: DataType
    var length: Int
    var bitmap: ArcPointer[Bitmap]
    var buffers: List[ArcPointer[Buffer]]
    var children: List[ArcPointer[ArrayData]]
    var offset: Int

    fn is_valid(self, index: Int) -> Bool:
        return self.bitmap[].unsafe_get(index + self.offset)

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

    fn _dynamic_write[W: Writer](self, index: Int, mut writer: W):
        """Write to the given stream dispatching on the dtype."""

        @parameter
        for known_type in [
            DType.bool,
            DType.int16,
            DType.int32,
            DType.int64,
            DType.int8,
            DType.float32,
            DType.float64,
            DType.uint16,
            DType.uint32,
            DType.uint64,
            DType.uint8,
        ]:
            if self.dtype.native == known_type:
                writer.write(self.buffers[0][].unsafe_get[known_type](index))
                return
        writer.write("dtype=")
        writer.write(self.dtype)

    fn write_to[W: Writer](self, mut writer: W):
        """
        Formats this ArrayData to the provided Writer.

        Parameters:
            W: A type conforming to the Writable trait.

        Args:
            writer: The object to write to.
        """

        for i in range(self.length):
            if self.is_valid(i):
                var real_index = i + self.offset
                self._dynamic_write(real_index, writer)
            else:
                writer.write("-")
            writer.write(" ")
            if i > 10:
                break

    fn __str__(self) -> String:
        return String.write(self)

    fn __repr__(self) -> String:
        return String.write(self)
