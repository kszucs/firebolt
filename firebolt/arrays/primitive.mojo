from memory import ArcPointer
from ..buffers import Buffer, Bitmap
from ..dtypes import *


fn drop_nulls[
    T: DType
](
    mut buffer: ArcPointer[Buffer],
    mut bitmap: ArcPointer[Bitmap],
    buffer_start: Int,
    buffer_end: Int,
) -> None:
    """Drop nulls from a region in the buffer.

    Args:
        buffer: The buffer to drop nulls from.
        bitmap: The validity bitmap.
        buffer_start: The start individualx of the buffer.
        buffer_end: The end index of the buffer.
    """
    var start = buffer_start
    # Find the end of a run of valid bits.
    start = start + bitmap[].count_leading_bits(start, value=True)
    while start < buffer_end:
        # Find the end of the run of nulls, could be just one null.
        var leading = bitmap[].count_leading_bits(start, value=False)
        var end_nulls = start + leading
        end_nulls = min(end_nulls, buffer_end)

        # Find the end of the run of values after the end of nulls.
        var end_values = end_nulls + bitmap[].count_leading_bits(
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
        bitmap[].unsafe_range_set(
            new_values_start, new_values_end - new_values_start, True
        )
        bitmap[].unsafe_range_set(
            new_values_end, new_nulls_end - new_values_end, False
        )

        # Get ready for next iteration.
        start = new_values_end


struct PrimitiveArray[T: DataType](Array):
    """An Arrow array of primitive types."""

    alias dtype = T
    alias scalar = Scalar[T.native]
    var data: ArrayData
    var bitmap: ArcPointer[Bitmap]
    var buffer: ArcPointer[Buffer]
    var capacity: Int

    fn __init__(out self, var data: ArrayData) raises:
        # TODO(kszucs): put a dtype constraint here
        if data.dtype != T:
            raise Error("Unexpected dtype")
        elif len(data.buffers) != 1:
            raise Error("PrimitiveArray requires exactly one buffer")

        self.data = data
        self.bitmap = data.bitmap
        self.buffer = data.buffers[0]
        self.capacity = data.length

    fn __init__(out self, capacity: Int = 0):
        self.capacity = capacity
        self.bitmap = ArcPointer(Bitmap.alloc(capacity))
        self.buffer = ArcPointer(Buffer.alloc[T.native](capacity))
        self.data = ArrayData(
            dtype=T,
            length=0,
            bitmap=self.bitmap,
            buffers=List(self.buffer),
            children=List[ArcPointer[ArrayData]](),
        )

    fn __moveinit__(out self, deinit existing: Self):
        self.data = existing.data^
        self.bitmap = existing.bitmap^
        self.buffer = existing.buffer^
        self.capacity = existing.capacity

    fn as_data(self) -> ArrayData:
        return self.data

    fn grow(mut self, capacity: Int):
        self.bitmap[].grow(capacity)
        self.buffer[].grow[T.native](capacity)
        self.capacity = capacity

    @always_inline
    fn __len__(self) -> Int:
        return self.data.length

    @always_inline
    fn is_valid(self, index: Int) -> Bool:
        return self.bitmap[].unsafe_get(index)

    @always_inline
    fn unsafe_get(self, index: Int) -> Self.scalar:
        return self.buffer[].unsafe_get[T.native](index)

    @always_inline
    fn unsafe_set(mut self, index: Int, value: Self.scalar):
        self.bitmap[].unsafe_set(index, True)
        self.buffer[].unsafe_set[T.native](index, value)

    @always_inline
    fn unsafe_append(mut self, value: Self.scalar):
        self.unsafe_set(self.data.length, value)
        self.data.length += 1

    @staticmethod
    fn nulls[T: DataType](size: Int) -> PrimitiveArray[T]:
        """Creates a new PrimitiveArray filled with null values."""
        var bitmap = Bitmap.alloc(size)
        bitmap.unsafe_range_set(0, size, False)
        var buffer = Buffer.alloc[T.native](size)
        return PrimitiveArray[T](
            data=ArrayData(
                dtype=T,
                length=size,
                bitmap=bitmap,
                buffers=List(buffer),
                children=List[ArcPointer[ArrayData]](),
            ),
            bitmap=bitmap,
            buffer=buffer,
            capacity=size,
        )

    fn append(mut self, value: Self.scalar):
        if self.data.length >= self.capacity:
            self.grow(self.capacity * 2)
        self.unsafe_append(value)

    # fn append(mut self, value: Optional[Self.scalar]):

    fn extend(mut self, values: List[self.scalar]):
        if self.__len__() + len(values) >= self.capacity:
            self.grow(self.capacity + len(values))
        for value in values:
            self.unsafe_append(value)

    fn drop_nulls[T: DType](mut self) -> None:
        """Drops null values from the Array.

        Currently we drop nulls from individual buffers, we do not delete buffers.
        """
        drop_nulls[T](self.buffer, self.bitmap, 0, self.data.length)
        self.data.length = self.bitmap[].buffer.bit_count()

    fn null_count(self) -> Int:
        """Returns the number of null values in the array."""
        var valid_count = self.bitmap[].buffer.bit_count()
        return self.data.length - valid_count


alias BoolArray = PrimitiveArray[bool_]
alias Int8Array = PrimitiveArray[int8]
alias Int16Array = PrimitiveArray[int16]
alias Int32Array = PrimitiveArray[int32]
alias Int64Array = PrimitiveArray[int64]
alias UInt8Array = PrimitiveArray[uint8]
alias UInt16Array = PrimitiveArray[uint16]
alias UInt32Array = PrimitiveArray[uint32]
alias UInt64Array = PrimitiveArray[uint64]
alias Float32Array = PrimitiveArray[float32]
alias Float64Array = PrimitiveArray[float64]
