from memory import UnsafePointer, memset_zero, memcpy
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
        mut self, ptr: UnsafePointer[UInt8], size: Int, owns: Bool = True
    ):
        self.ptr = ptr
        self.size = size
        self.owns = owns

    fn __moveinit__(mut self, owned existing: Self):
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
