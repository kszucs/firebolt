from memory import UnsafePointer, ArcPointer

import math
from python import Python, PythonObject
from sys.ffi import c_char

from .dtypes import *
from .arrays import *

alias ARROW_FLAG_NULLABLE = 2


alias CSchemaReleaseFunction = fn (
    schema: UnsafePointer[CArrowSchema]
) -> NoneType
alias CArrayReleaseFunction = fn (
    schema: UnsafePointer[CArrowArray]
) -> NoneType


@value
struct CArrowSchema:
    var format: UnsafePointer[c_char]
    var name: UnsafePointer[c_char]
    var metadata: UnsafePointer[c_char]
    var flags: Int64
    var n_children: Int64
    var children: UnsafePointer[UnsafePointer[CArrowSchema]]
    var dictionary: UnsafePointer[CArrowSchema]
    # TODO(kszucs): release callback must be called otherwise memory gets leaked
    var release: UnsafePointer[CSchemaReleaseFunction]
    var private_data: UnsafePointer[NoneType]

    # fn __del__(owned self):
    #     var this = UnsafePointer.address_of(self)
    #     if self.release:
    #         self.release[](this)

    @staticmethod
    fn from_pyarrow(pyobj: PythonObject) raises -> CArrowSchema:
        var ptr = UnsafePointer[CArrowSchema].alloc(1)
        pyobj._export_to_c(Int(ptr))
        return ptr.take_pointee()

    fn to_pyarrow(self) raises -> PythonObject:
        var pa = Python.import_module("pyarrow")
        var ptr = UnsafePointer[CArrowSchema].address_of(self)
        return pa.Schema._import_from_c(Int(ptr))

    @staticmethod
    fn from_dtype(dtype: DataType) -> CArrowSchema:
        var fmt: String
        var n_children: Int64 = 0
        var children = UnsafePointer[UnsafePointer[CArrowSchema]]()

        if dtype == null:
            fmt = "n"
        elif dtype == bool_:
            fmt = "b"
        elif dtype == int8:
            fmt = "c"
        elif dtype == uint8:
            fmt = "C"
        elif dtype == int16:
            fmt = "s"
        elif dtype == uint16:
            fmt = "S"
        elif dtype == int32:
            fmt = "i"
        elif dtype == uint32:
            fmt = "I"
        elif dtype == int64:
            fmt = "l"
        elif dtype == uint64:
            fmt = "L"
        elif dtype == float16:
            fmt = "e"
        elif dtype == float32:
            fmt = "f"
        elif dtype == float64:
            fmt = "g"
        elif dtype == binary:
            fmt = "z"
        elif dtype == string:
            fmt = "u"
        elif dtype.is_struct():
            print("EEE")

            fmt = "+s"
            n_children = Int(len(dtype.fields))
            children = UnsafePointer[UnsafePointer[CArrowSchema]].alloc(
                Int(n_children)
            )

            for i in range(n_children):
                var child = CArrowSchema.from_field(dtype.fields[i])
                children[i].init_pointee_move(child)
        else:
            fmt = ""
            # constrained[False, "Unknown dtype"]()

        return CArrowSchema(
            format=fmt.unsafe_cstr_ptr(),
            name=UnsafePointer[c_char](),
            metadata=UnsafePointer[c_char](),
            flags=0,
            n_children=n_children,
            children=children,
            dictionary=UnsafePointer[CArrowSchema](),
            # TODO(kszucs): currently there is no way to pass a mojo callback to C
            release=UnsafePointer[CSchemaReleaseFunction](),
            private_data=UnsafePointer[NoneType](),
        )

    @staticmethod
    fn from_field(field: Field) -> CArrowSchema:
        var flags: Int64 = 0  # TODO: nullable

        return CArrowSchema(
            format="".unsafe_cstr_ptr(),
            name=field.name.unsafe_cstr_ptr(),
            metadata="".unsafe_cstr_ptr(),
            flags=flags,
            n_children=0,
            children=UnsafePointer[UnsafePointer[CArrowSchema]](),
            dictionary=UnsafePointer[CArrowSchema](),
            # TODO(kszucs): currently there is no way to pass a mojo callback to C
            release=UnsafePointer[CSchemaReleaseFunction](),
            private_data=UnsafePointer[NoneType](),
        )

    fn to_dtype(self) raises -> DataType:
        var fmt = StringSlice[__origin_of(self.format)](
            unsafe_from_utf8_cstr_ptr=self.format
        )
        # TODO(kszucs): not the nicest, but dictionary literals are not supported yet
        if fmt == "n":
            return null
        elif fmt == "b":
            return bool_
        elif fmt == "c":
            return int8
        elif fmt == "C":
            return uint8
        elif fmt == "s":
            return int16
        elif fmt == "S":
            return uint16
        elif fmt == "i":
            return int32
        elif fmt == "I":
            return uint32
        elif fmt == "l":
            return int64
        elif fmt == "L":
            return uint64
        elif fmt == "e":
            return float16
        elif fmt == "f":
            return float32
        elif fmt == "g":
            return float64
        elif fmt == "z":
            return binary
        elif fmt == "u":
            return string
        elif fmt == "+l":
            var field = self.children[0][].to_field()
            return list_(field.dtype)
        elif fmt == "+s":
            var fields = List[Field]()
            for i in range(self.n_children):
                fields.append(self.children[i][].to_field())
            return struct_(fields)
        else:
            raise Error("Unknown format")

    fn to_field(self) raises -> Field:
        var name = StringSlice[__origin_of(self)](
            unsafe_from_utf8_cstr_ptr=self.name
        )
        var dtype = self.to_dtype()
        var nullable = self.flags & ARROW_FLAG_NULLABLE
        return Field(String(name), dtype, nullable == 0)


@value
struct CArrowArray:
    var length: Int64
    var null_count: Int64
    var offset: Int64
    var n_buffers: Int64
    var n_children: Int64
    var buffers: UnsafePointer[UnsafePointer[NoneType]]
    var children: UnsafePointer[UnsafePointer[CArrowArray]]
    var dictionary: UnsafePointer[CArrowArray]
    var release: UnsafePointer[CArrayReleaseFunction]
    var private_data: UnsafePointer[NoneType]

    @staticmethod
    fn from_pyarrow(pyobj: PythonObject) raises -> CArrowArray:
        var ptr = UnsafePointer[CArrowArray].alloc(1)
        pyobj._export_to_c(Int(ptr))
        return ptr.take_pointee()

    fn to_array(self, dtype: DataType) raises -> ArrayData:
        var bitmap: ArcPointer[Buffer]
        if self.buffers[0]:
            bitmap = Buffer.view(self.buffers[0], self.length, DType.bool)
        else:
            # bitmaps are allowed to be nullptrs by the specification, in this
            # case we allocate a new buffer to hold the null bitmap
            bitmap = Buffer.alloc[DType.uint8](self.length)

        var buffers = List[ArcPointer[Buffer]]()
        if dtype.is_numeric():
            var buffer = Buffer.view(self.buffers[1], self.length, dtype.native)
            buffers.append(buffer^)
        elif dtype == string:
            var offsets = Buffer.view(
                self.buffers[1], self.length + 1, DType.uint32
            )
            var values_size = Int(offsets.unsafe_get(Int(self.length)))
            var values = Buffer.view(self.buffers[2], values_size, DType.uint8)
            buffers.append(offsets^)
            buffers.append(values^)
        elif dtype.is_list():
            var offsets = Buffer.view(
                self.buffers[1], self.length + 1, DType.uint32
            )
            buffers.append(offsets^)
        else:
            raise Error("Unknown dtype")

        var children = List[ArcPointer[ArrayData]]()
        for i in range(self.n_children):
            var child_field = dtype.fields[i]
            var child_array = self.children[i][].to_array(child_field.dtype)
            children.append(child_array^)

        return ArrayData(
            dtype=dtype,
            length=Int(self.length),
            bitmap=bitmap,
            buffers=buffers,
            children=children,
        )
