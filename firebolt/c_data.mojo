from sys.ffi import external_call, DLHandle, c_char
from memory import UnsafePointer, ArcPointer, memcpy
from sys import size_of

import math
from python import Python, PythonObject
from python._cpython import CPython, PyObjectPtr
from sys.ffi import c_char
from io.write import Writable, Writer

from .dtypes import *
from .arrays import *

alias ARROW_FLAG_NULLABLE = 2

# This type of the function argument is really CArrowSchema but we are getting errors with: recursive reference to declaration.
alias CSchemaReleaseFunction = fn (schema: UnsafePointer[UInt64]) -> NoneType
# This type of the function argument is really CArrowArray but we are getting errors with: recursive reference to declaration.
alias CArrayReleaseFunction = fn (schema: UnsafePointer[UInt64]) -> NoneType


@fieldwise_init
struct CArrowSchema(Copyable, Movable, Representable, Stringable, Writable):
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

    fn __del__(deinit self):
        var this = UnsafePointer(to=self).bitcast[UInt64]()
        if self.release:
            # Calling the function leads to a crash.
            # self.release[](this)
            pass

    @staticmethod
    fn from_pyarrow(pyobj: PythonObject) raises -> CArrowSchema:
        var ptr = UnsafePointer[CArrowSchema].alloc(1)
        pyobj._export_to_c(Int(ptr))
        return ptr.take_pointee()

    fn to_pyarrow(self) raises -> PythonObject:
        var pa = Python.import_module("pyarrow")
        var ptr = UnsafePointer(to=self)
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

        var field_name = field.name
        return CArrowSchema(
            format="".unsafe_cstr_ptr(),
            name=field_name.unsafe_cstr_ptr(),
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
            unsafe_from_utf8_ptr=self.format
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
            raise Error("Unknown format: " + fmt)

    fn to_field(self) raises -> Field:
        var name = StringSlice[__origin_of(self)](
            unsafe_from_utf8_ptr=self.name
        )
        var dtype = self.to_dtype()
        var nullable = self.flags & ARROW_FLAG_NULLABLE
        return Field(String(name), dtype, nullable != 0)

    fn write_to[W: Writer](self, mut writer: W):
        """
        Formats this CArrowSchema to the provided Writer.

        Parameters:
            W: A type conforming to the Writable trait.

        Args:
            writer: The object to write to.
        """
        writer.write("CArrowSchema(")
        writer.write('name="')
        writer.write(StringSlice(unsafe_from_utf8_ptr=self.name))
        writer.write('", ')
        writer.write('format="')
        writer.write(StringSlice(unsafe_from_utf8_ptr=self.format))
        writer.write('", ')
        if self.metadata:
            writer.write('metadata="')
            writer.write(self.metadata)
            writer.write('", ')
        writer.write("n_children=")
        writer.write(self.n_children)
        writer.write(")")

    fn __str__(self) -> String:
        return String.write(self)

    fn __repr__(self) -> String:
        return String.write(self)


@fieldwise_init
struct CArrowArray(Copyable, Movable):
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
        var bitmap: ArcPointer[Bitmap]
        if self.buffers[0]:
            bitmap = ArcPointer(
                Bitmap(Buffer.view(self.buffers[0], self.length, DType.bool))
            )
        else:
            # bitmaps are allowed to be nullptrs by the specification, in this
            # case we allocate a new buffer to hold the null bitmap
            bitmap = ArcPointer(Bitmap.alloc(self.length))
            bitmap[].unsafe_range_set(0, self.length, True)

        var buffers = List[ArcPointer[Buffer]]()
        if dtype.is_numeric() or dtype == bool_:
            var buffer = Buffer.view(self.buffers[1], self.length, dtype.native)
            buffers.append(ArcPointer(buffer^))
        elif dtype == string:
            var offsets = Buffer.view(
                self.buffers[1], self.length + 1, DType.uint32
            )
            var values_size = Int(offsets.unsafe_get(Int(self.length)))
            var values = Buffer.view(self.buffers[2], values_size, DType.uint8)
            buffers.append(ArcPointer(offsets^))
            buffers.append(ArcPointer(values^))
        elif dtype.is_list():
            var offsets = Buffer.view(
                self.buffers[1], self.length + 1, DType.uint32
            )
            buffers.append(ArcPointer(offsets^))
        elif dtype.is_struct():
            # Since the children buffers are handled below there is nothing to do here.
            pass
        else:
            raise Error("Unknown dtype: " + String(dtype))

        var children = List[ArcPointer[ArrayData]]()
        for i in range(self.n_children):
            var child_field = dtype.fields[i]
            var child_array = self.children[i][].to_array(child_field.dtype)
            children.append(ArcPointer(child_array^))

        return ArrayData(
            dtype=dtype,
            length=Int(self.length),
            bitmap=bitmap,
            buffers=buffers,
            children=children,
            offset=Int(self.offset),
        )


# See: https://arrow.apache.org/docs/format/CStreamInterface.html
#
# We are getting some compilation errors with many "recursive" function definitions, i.e. functions in
# CArrowArrayStream that take a CArrowArrayStream as an argument. The error is: recursive reference to declaration.
#
# As a workaround we define twp versions
# of the CArrowArrayStream:
#   - CArrowArrayStreamOpaque defines the overall shape of the struct using opaque function prototypes.
#   - CArrowArrayStream defines the struct with the actual function signatures defined in terms of the Opaque variant above.
#
# An alternative could be to define `get_schema` and friends as methods on the struct and self would have the right type.
# It is not clear if the resulting ABI would be guaranteed to be compatible with C.
alias AnyFunction = fn (OpaquePointer) -> UInt


@fieldwise_init
@register_passable("trivial")
struct CArrowArrayStreamOpaque(Copyable, Movable):
    # Callbacks providing stream functionality
    var get_schema: AnyFunction
    var get_next: AnyFunction
    var get_last_error: AnyFunction

    # Release callback
    var release: AnyFunction

    # Opaque producer-specific data
    var private_data: OpaquePointer


@fieldwise_init
@register_passable("trivial")
struct CArrowArrayStream(Copyable, Movable):
    # Callbacks providing stream functionality
    var get_schema: fn (
        stream: UnsafePointer[CArrowArrayStreamOpaque],
        out_schema: UnsafePointer[CArrowSchema],
    ) -> UInt
    var get_next: fn (
        stream: UnsafePointer[CArrowArrayStreamOpaque],
        out_array: UnsafePointer[CArrowArray],
    ) -> UInt
    var get_last_error: fn (
        stream: UnsafePointer[CArrowArrayStreamOpaque]
    ) -> UnsafePointer[c_char]

    # Release callback
    var release: fn (stream: UnsafePointer[CArrowArrayStreamOpaque]) -> None

    # Opaque producer-specific data
    var private_data: OpaquePointer


@fieldwise_init
struct ArrowArrayStream(Copyable, Movable):
    """Provide an fiendly interface to the C Arrow Array Stream."""

    var c_arrow_array_stream: UnsafePointer[CArrowArrayStream]

    @staticmethod
    fn from_pyarrow(
        pyobj: PythonObject, cpython: CPython
    ) raises -> ArrowArrayStream:
        """Ask a PyArrow table for its arrow array stream interface."""
        var stream = pyobj.__arrow_c_stream__()
        var ptr = cpython.PyCapsule_GetPointer(
            stream.steal_data(), "arrow_array_stream"
        )
        if not ptr:
            raise Error("Failed to get the arrow array stream pointer")

        var alt = ptr.bitcast[CArrowArrayStream]()
        return ArrowArrayStream(alt)

    fn _opaque_array_stream(self) -> UnsafePointer[CArrowArrayStreamOpaque]:
        """Return the arrow array as its opaque C variant."""
        return self.c_arrow_array_stream.bitcast[CArrowArrayStreamOpaque]()

    fn c_schema(self) raises -> CArrowSchema:
        """Return the C variant of the Arrow Schema."""
        var schema = UnsafePointer[CArrowSchema].alloc(1)
        var function = self.c_arrow_array_stream[].get_schema
        var err = function(self._opaque_array_stream(), schema)
        if err != 0:
            raise Error("Failed to get schema " + String(err))
        if not schema:
            raise Error("The schema pointer is null")
        return schema.take_pointee()

    fn c_next(self) raises -> CArrowArray:
        """Return the next buffer in the streeam."""
        var arrow_array = UnsafePointer[CArrowArray].alloc(1)
        var function = self.c_arrow_array_stream[].get_next
        var err = function(self._opaque_array_stream(), arrow_array)
        if err != 0:
            raise Error("Failed to get next arrow array " + String(err))
        if not arrow_array:
            raise Error("The arrow array pointer is null")
        return arrow_array.take_pointee()
