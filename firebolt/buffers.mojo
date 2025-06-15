from memory import UnsafePointer, memset_zero, memcpy, ArcPointer, Span, memset
from sys.info import sizeof, simdbytewidth
import math
from bit import pop_count, count_trailing_zeros


fn _required_bytes(length: Int, T: DType) -> Int:
    var size: Int
    if T is DType.bool:
        size = math.ceildiv(length, 8)
    else:
        size = length * T.sizeof()
    return math.align_up(size, 64)


alias simd_width = simdbytewidth()

alias simd_widths = (simd_width, simd_width // 2, 1)


struct Buffer(Movable):
    var ptr: UnsafePointer[UInt8]
    var size: Int
    var owns: Bool

    fn __init__(
        out self, ptr: UnsafePointer[UInt8], size: Int, owns: Bool = True
    ):
        self.ptr = ptr
        self.size = size
        self.owns = owns

    fn __moveinit__(out self, owned existing: Self):
        self.ptr = existing.ptr
        self.size = existing.size
        self.owns = existing.owns

    fn swap(mut self, mut other: Self):
        """Swap the content of this buffer with another buffer."""

        var tmp_ptr = self.ptr
        var tmp_size = self.size
        var tmp_owns = self.owns
        self.ptr = other.ptr
        self.size = other.size
        self.owns = other.owns
        other.ptr = tmp_ptr
        other.size = tmp_size
        other.owns = tmp_owns

    @staticmethod
    fn alloc[I: Intable, //, T: DType = DType.uint8](length: I) -> Buffer:
        var size = _required_bytes(Int(length), T)
        var ptr = UnsafePointer[UInt8, alignment=64].alloc(size)
        memset_zero(ptr.bitcast[UInt8](), size)
        return Buffer(ptr, size)

    @staticmethod
    fn view[
        I: Intable, //
    ](
        ptr: UnsafePointer[NoneType], length: I, dtype: DType = DType.uint8
    ) -> Buffer:
        var size = _required_bytes(Int(length), dtype)
        return Buffer(ptr.bitcast[UInt8](), size, owns=False)

    @always_inline
    fn offset(self, index: Int) -> UnsafePointer[UInt8]:
        return (self.ptr + index).bitcast[UInt8]()

    fn grow[I: Intable, //, T: DType = DType.uint8](mut self, target_length: I):
        if self.length[T]() >= Int(target_length):
            return

        var new = Buffer.alloc[T](target_length)
        memcpy(new.ptr.bitcast[UInt8](), self.ptr.bitcast[UInt8](), self.size)
        self.swap(new)

    fn __del__(owned self):
        if self.owns:
            self.ptr.free()

    @always_inline
    fn length[T: DType = DType.uint8](self) -> Int:
        @parameter
        if T is DType.bool:
            return self.size * 8
        else:
            return self.size // sizeof[T]()

    @always_inline
    fn unsafe_get[T: DType = DType.uint8](self, index: Int) -> Scalar[T]:
        alias output = Scalar[T]

        @parameter
        if T is DType.bool:
            var byte_index = index // 8
            var bit_index = index % 8
            var byte = self.ptr[byte_index]
            return output((byte & (1 << bit_index)) != 0)
        else:
            return self.ptr.bitcast[output]()[index]

    @always_inline
    fn unsafe_set[
        T: DType = DType.uint8
    ](mut self, index: Int, value: Scalar[T]):
        @parameter
        if T is DType.bool:
            var byte_index = index // 8
            var bit_index = index % 8
            var byte = self.ptr[byte_index]
            if value:
                self.ptr[byte_index] = byte | (1 << bit_index)
            else:
                self.ptr[byte_index] = byte & ~(1 << bit_index)
        else:
            alias output = Scalar[T]
            self.ptr.bitcast[output]()[index] = value


struct Bitmap(Movable, Writable):
    """Hold information about the null records in an array."""

    var buffer: Buffer

    @staticmethod
    fn alloc[I: Intable](length: I) -> Bitmap:
        return Bitmap(Buffer.alloc[DType.bool](length))

    fn __init__(out self, owned buffer: Buffer):
        self.buffer = buffer^

    fn __moveinit__(out self, owned existing: Self):
        self.buffer = existing.buffer^

    fn write_to[W: Writer](self, mut writer: W):
        """
        Formats this buffer to the provided Writer.

        Parameters:
            W: A type conforming to the Writable trait.

        Args:
            writer: The object to write to.
        """

        for i in range(self.length()):
            var value = self.unsafe_get(i)
            if value:
                writer.write("T")
            else:
                writer.write("f")
            if i > 16:
                writer.write("...")
                break

    fn unsafe_get(self, index: Int) -> Bool:
        return self.buffer.unsafe_get[DType.bool](index)

    fn unsafe_set(mut self, index: Int, value: Bool) -> None:
        self.buffer.unsafe_set[DType.bool](index, value)

    @always_inline
    fn length(self) -> Int:
        return self.buffer.length[DType.bool]()

    @always_inline
    fn size(self) -> Int:
        return self.buffer.size

    fn grow[I: Intable](mut self, target_length: I):
        return self.buffer.grow[DType.bool](target_length)

    fn bit_count(self) -> Int:
        """The number of bits with value 1 in the Bitmap."""
        var start = 0
        var count = 0
        while start < self.buffer.size:
            if self.buffer.size - start > simd_width:
                count += (
                    self.buffer.offset(start)
                    .load[width=simd_width]()
                    .reduce_bit_count()
                )
                start += simd_width
            else:
                count += (
                    self.buffer.offset(start).load[width=1]().reduce_bit_count()
                )
                start += 1
        return count

    fn count_leading_bits(self, start: Int = 0, value: Bool = False) -> Int:
        """Count the number of leading bits with the given value in the bitmap, starting at a given posiion.

        Note that index 0 in the bitmap translates to right most bit in the first byte of the buffer.
        So when we are looking for leading zeros from a bitmap standpoing we need to look at
        trailing zeros in the bitmap's associated buffer.

        The SIMD API available looks at leading zeros only, we negate the input when needed.

        Args:
          start: The position where we should start counting.
          value: The value of the bits we want to count.

        Returns:
          The number of leadinging bits with the given value in the bitmap.
        """

        var count = 0
        var index = start // 8
        var bit_in_first_byte = start % 8

        if bit_in_first_byte != 0:
            # Process the partial first byte by applying a mask.
            var loaded = self.buffer.offset(index).load[width=1]()
            if value:
                loaded = ~loaded
            var mask = (1 << bit_in_first_byte) - 1
            loaded &= ~mask
            leading_zeros = Int(count_trailing_zeros(loaded))
            if leading_zeros == 0:
                return count
            count = leading_zeros - bit_in_first_byte
            if leading_zeros != 8:
                # The first byte has some bits of the other value, just return the count.
                return count

            index += 1

        # Process full bytes.
        while index < self.size():

            @parameter
            for width_index in range(len(simd_widths)):
                alias width = simd_widths[width_index]
                if self.size() - index >= width:
                    var loaded = self.buffer.offset(index).load[width=width]()
                    if value:
                        loaded = ~loaded
                    var leading_zeros = count_trailing_zeros(loaded)
                    for i in range(width):
                        count += Int(leading_zeros[i])
                        if leading_zeros[i] != 8:
                            return count
                    index += width
                    # break from the simd widths loop
                    break
        return count

    fn count_leading_zeros(self, start: Int = 0) -> Int:
        """Count the number of leading 0s in the given value in the bitmap, starting at a given posiion.

        Note that index 0 in the bitmap translates to right most bit in the first byte of the buffer.
        So when we are looking for leading zeros from a bitmap standpoing we need to look at
        trailing zeros in the bitmap's associated buffer.

        Args:
            start: The position where we should start counting.

        Returns:
             The number of leading zeros in the bitmap.
        """
        return self.count_leading_bits(start, value=False)

    fn count_leading_ones(self, start: Int = 0) -> Int:
        """Count the number of leading 1s in the given value in the bitmap, starting at a given posiion.

        Note that index 0 in the bitmap translates to right most bit in the first byte of the buffer.
        So when we are looking for leading zeros from a bitmap standpoing we need to look at
        trailing zeros in the bitmap's associated buffer.

        Args:
          start: The position where we should start counting.

        Returns:
          The number of leading ones in the bitmap.
        """
        return self.count_leading_bits(start, value=True)

    fn extend(
        mut self,
        other: Bitmap,
        start: Int,
        length: Int,
    ) -> None:
        """Extends the bitmap with the other's array's bitmap.

        Args:
            other: The bitmap to take content from.
            start: The starting index in the destination array.
            length: The number of elements to copy from the source array.
        """
        var desired_size = _required_bytes(start + length, DType.bool)
        self.buffer.grow[DType.bool](desired_size)

        for i in range(length):
            self.unsafe_set(i + start, other.unsafe_get(i))

    fn partial_byte_set(
        mut self,
        byte_index: Int,
        bit_pos_start: Int,
        bit_pos_end: Int,
        value: Bool,
    ) -> None:
        """Set a range of bits in one specific byte of the bitmap to the specified value.
        """

        debug_assert(
            bit_pos_start >= 0
            and bit_pos_end <= 8
            and bit_pos_start <= bit_pos_end,
            "Invalid range: ",
            bit_pos_start,
            " to ",
            bit_pos_end,
        )

        # Process the partial byte at the start, if appropriate.
        var mask = (1 << (bit_pos_end - bit_pos_start)) - 1
        mask = mask << bit_pos_start
        var initial_value = self.buffer.unsafe_get[DType.uint8](byte_index)
        var buffer_value = initial_value
        if value:
            buffer_value = buffer_value | mask
        else:
            buffer_value = buffer_value & ~mask
        self.buffer.unsafe_set[DType.uint8](byte_index, buffer_value)

    fn unsafe_range_set(mut self, start: Int, length: Int, value: Bool) -> None:
        """Set a range of bits in the bitmap to the specified value.

        Args:
            start: The starting index in the bitmap.
            length: The number of bits to set.
            value: The value to set the bits to.
        """

        # Process the partial byte at the ends.
        var start_index = start // 8
        var bit_pos_start = start % 8
        var end_index = (start + length) // 8
        var bit_pos_end = (start + length) % 8

        if bit_pos_start != 0 or bit_pos_end != 0:
            if start_index == end_index:
                self.partial_byte_set(
                    start_index, bit_pos_start, bit_pos_end, value
                )
            else:
                if bit_pos_start != 0:
                    self.partial_byte_set(start_index, bit_pos_start, 8, value)
                    start_index += 1
                if bit_pos_end != 0:
                    self.partial_byte_set(end_index, 0, bit_pos_end, value)
                    end_index -= 1

        # Now take care of the full bytes.
        if end_index > start_index:
            var byte_value = 255 if value else 0
            memset(
                self.buffer.offset(start_index),
                value=byte_value,
                count=end_index - start_index,
            )
