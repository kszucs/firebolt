from .primitive import *
from ..buffers import Buffer, Bitmap
from sys.info import sizeof
from bit import pop_count


trait Array(Movable, Sized):
    fn as_data(self) -> ArrayData:
        ...


@value
struct ArrayData(Movable, Writable):
    """ArrayData is the lower level abstraction directly usable by the library consumer.

    Equivalent with https://github.com/apache/arrow/blob/7184439dea96cd285e6de00e07c5114e4919a465/cpp/src/arrow/array/data.h#L62-L84.
    """

    var dtype: DataType
    var length: Int
    var bitmap: ArcPointer[Bitmap]
    var buffers: List[ArcPointer[Buffer]]
    var children: List[ArcPointer[ArrayData]]

    fn is_valid(self, index: Int) -> Bool:
        return self.bitmap[].unsafe_get(index)

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

    fn _drop_nulls[
        T: DType
    ](
        mut self, buffer: ArcPointer[Buffer], buffer_start: Int, buffer_end: Int
    ) -> None:
        """Drop nulls from a region in the buffer.

        Args:
            buffer: The buffer to drop nulls from.
            buffer_start: The start index of the buffer.
            buffer_end: The end index of the buffer.
        """
        var start = buffer_start
        # Find the end of a run of valid bits.
        start = start + self.bitmap[].count_leading_bits(start, value=True)
        while start < buffer_end:
            # Find the end of the run of nulls, could be just one null.
            var leading = self.bitmap[].count_leading_bits(start, value=False)
            var end_nulls = start + leading
            end_nulls = min(end_nulls, buffer_end)

            # Find the end of the run of values after the end of nulls.
            var end_values = end_nulls + self.bitmap[].count_leading_bits(
                end_nulls, value=True
            )
            end_values = min(end_values, buffer_end)
            var values_len = end_values - end_nulls
            if values_len == 0:
                # No valid entries to move, just skip.
                start = end_nulls
                continue

            # Compact the data.
            memcpy(
                buffer[].offset(start),
                buffer[].offset(end_nulls),
                values_len * sizeof[T](),
            )
            # Adjust the bitmp.
            var new_values_start = start
            var new_values_end = start + values_len
            var new_nulls_end = end_values
            self.bitmap[].unsafe_range_set(
                new_values_start, new_values_end - new_values_start, True
            )
            self.bitmap[].unsafe_range_set(
                new_values_end, new_nulls_end - new_values_end, False
            )

            # Get ready for next iteration.
            start = new_values_end

    fn drop_nulls[T: DType](mut self) -> None:
        """Drops null values from the Array.

        Currently we drop nulls from individual buffers, we do not delete buffers.
        """
        # Track the start position in the validity bitmap.
        var buffer_start = 0
        # Process each buffer.
        for buffer_index in range(len(self.buffers)):
            var buffer = self.buffers[buffer_index]
            buffer_end = buffer_start + buffer[].length[T]()
            self._drop_nulls[T](buffer, buffer_start, buffer_end)
            buffer_start = buffer_end

        # Set the length of the array to the number of valid entries.
        self.length = self.bitmap[].buffer.bit_count()

    fn null_count(self) -> Int:
        """Returns the number of null values in the array."""
        var valid_count = self.bitmap[].buffer.bit_count()
        return self.length - valid_count

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
                writer.write(self.buffers[0][].unsafe_get(i))
            else:
                writer.write("-")
            writer.write(" ")
            if i > 10:
                break
