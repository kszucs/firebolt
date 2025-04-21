from memory import UnsafePointer, memset_zero, memcpy, ArcPointer
from sys.info import sizeof
import math


fn _required_bytes(length: Int, T: DType) -> Int:
    var size: Int
    if T is DType.bool:
        size = math.ceildiv(length, 8)
    else:
        size = length * T.sizeof()
    return math.align_up(size, 64)


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
        self.ptr.free()
        self.ptr = new.ptr
        self.size = new.size
        new.ptr = UnsafePointer[UInt8]()

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


struct Bitmap(Writable):
    """Hold information about the null records in an array.

    This is a specialized Buffer, not sure how to share the code.
    """

    var ptr: UnsafePointer[UInt8]
    var size: Int
    var owns: Bool

    @staticmethod
    fn alloc[I: Intable](length: I) -> Bitmap:
        var size = _required_bytes(Int(length), DType.bool)
        var ptr = UnsafePointer[UInt8, alignment=64].alloc(size)
        memset_zero(ptr.bitcast[UInt8](), size)
        return Bitmap(ptr, size)

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

    fn __del__(owned self):
        if self.owns:
            self.ptr.free()

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

    @always_inline
    fn as_buffer(ref self) -> UnsafePointer[Buffer]:
        """Cast as a Buffer."""
        return UnsafePointer.address_of(self).bitcast[Buffer]()

    @staticmethod
    fn view[
        I: Intable, //
    ](
        ptr: UnsafePointer[NoneType], length: I, dtype: DType = DType.uint8
    ) -> Bitmap:
        var size = _required_bytes(Int(length), dtype)
        return Bitmap(ptr.bitcast[UInt8](), size, owns=False)

    fn unsafe_get(self, index: Int) -> Bool:
        return self.as_buffer()[].unsafe_get[DType.bool](index)

    fn unsafe_set(mut self, index: Int, value: Bool) -> None:
        self.as_buffer()[].unsafe_set[DType.bool](index, True)

    fn length(self) -> Int:
        return self.as_buffer()[].length[DType.bool]()

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
        self.as_buffer()[].grow[DType.bool](desired_size)

        for i in range(length):
            self.unsafe_set(i + start, other.unsafe_get(i))
