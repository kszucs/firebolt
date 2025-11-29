from sys.ffi import external_call, c_char
from memory import LegacyUnsafePointer, ArcPointer, memcpy
from sys import size_of

import math
from python import Python, PythonObject
from python._cpython import CPython, PyObjectPtr
from sys.ffi import c_char
from io.write import Writable, Writer

from .dtypes import *
from .arrays import *

comptime ARROW_FLAG_NULLABLE = 2

# This type of the function argument is really CArrowSchema but we are getting errors with: recursive reference to declaration.
comptime CSchemaReleaseFunction = fn (
    schema: LegacyUnsafePointer[UInt64]
) -> NoneType
# This type of the function argument is really CArrowArray but we are getting errors with: recursive reference to declaration.
comptime CArrayReleaseFunction = fn (
    schema: LegacyUnsafePointer[UInt64]
) -> NoneType


@fieldwise_init
struct CArrowSchema(Copyable, Movable, Representable, Stringable, Writable):
    var format: LegacyUnsafePointer[c_char]
    var name: LegacyUnsafePointer[c_char]
    var metadata: LegacyUnsafePointer[c_char]
    var flags: Int64
    var n_children: Int64
    var children: LegacyUnsafePointer[LegacyUnsafePointer[CArrowSchema]]
    var dictionary: LegacyUnsafePointer[CArrowSchema]
    # TODO(kszucs): release callback must be called otherwise memory gets leaked
    var release: LegacyUnsafePointer[CSchemaReleaseFunction]
    var private_data: LegacyUnsafePointer[NoneType]

    fn __del__(deinit self):
        var this = LegacyUnsafePointer(to=self).bitcast[UInt64]()
        if self.release:
            # Calling the function leads to a crash.
            # self.release[](this)
            pass

    @staticmethod
    fn from_pyarrow(pyobj: PythonObject) raises -> CArrowSchema:
        var ptr = LegacyUnsafePointer[CArrowSchema].alloc(1)
        pyobj._export_to_c(Int(ptr))
        return ptr.take_pointee()

    fn to_pyarrow(self) raises -> PythonObject:
        var pa = Python.import_module("pyarrow")
        var ptr = LegacyUnsafePointer(to=self)
        return pa.Schema._import_from_c(Int(ptr))

    @staticmethod
    fn from_dtype(dtype: DataType) -> CArrowSchema:
        var fmt: String
        var n_children: Int64 = 0
        var children = LegacyUnsafePointer[LegacyUnsafePointer[CArrowSchema]]()

        if dtype == materialize[null]():
            fmt = "n"
        elif dtype == materialize[bool_]():
            fmt = "b"
        elif dtype == materialize[int8]():
            fmt = "c"
        elif dtype == materialize[uint8]():
            fmt = "C"
        elif dtype == materialize[int16]():
            fmt = "s"
        elif dtype == materialize[uint16]():
            fmt = "S"
        elif dtype == materialize[int32]():
            fmt = "i"
        elif dtype == materialize[uint32]():
            fmt = "I"
        elif dtype == materialize[int64]():
            fmt = "l"
        elif dtype == materialize[uint64]():
            fmt = "L"
        elif dtype == materialize[float16]():
            fmt = "e"
        elif dtype == materialize[float32]():
            fmt = "f"
        elif dtype == materialize[float64]():
            fmt = "g"
        elif dtype == materialize[binary]():
            fmt = "z"
        elif dtype == materialize[string]():
            fmt = "u"
        elif dtype.is_struct():
            print("EEE")

            fmt = "+s"
            n_children = Int(len(dtype.fields))
            children = LegacyUnsafePointer[
                LegacyUnsafePointer[CArrowSchema]
            ].alloc(Int(n_children))

            for i in range(n_children):
                var child = CArrowSchema.from_field(dtype.fields[i])
                children[i].init_pointee_move(child^)
        else:
            fmt = ""
            # constrained[False, "Unknown dtype"]()

        return CArrowSchema(
            format=fmt.unsafe_cstr_ptr(),
            name=LegacyUnsafePointer[c_char](),
            metadata=LegacyUnsafePointer[c_char](),
            flags=0,
            n_children=n_children,
            children=children,
            dictionary=LegacyUnsafePointer[CArrowSchema](),
            # TODO(kszucs): currently there is no way to pass a mojo callback to C
            release=LegacyUnsafePointer[CSchemaReleaseFunction](),
            private_data=LegacyUnsafePointer[NoneType](),
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
            children=LegacyUnsafePointer[LegacyUnsafePointer[CArrowSchema]](),
            dictionary=LegacyUnsafePointer[CArrowSchema](),
            # TODO(kszucs): currently there is no way to pass a mojo callback to C
            release=LegacyUnsafePointer[CSchemaReleaseFunction](),
            private_data=LegacyUnsafePointer[NoneType](),
        )

    fn to_dtype(self) raises -> DataType:
        var fmt = StringSlice(unsafe_from_utf8_ptr=UnsafePointer(self.format))
        # TODO(kszucs): not the nicest, but dictionary literals are not supported yet
        if fmt == "n":
            return materialize[null]()
        elif fmt == "b":
            return materialize[bool_]()
        elif fmt == "c":
            return materialize[int8]()
        elif fmt == "C":
            return materialize[uint8]()
        elif fmt == "s":
            return materialize[int16]()
        elif fmt == "S":
            return materialize[uint16]()
        elif fmt == "i":
            return materialize[int32]()
        elif fmt == "I":
            return materialize[uint32]()
        elif fmt == "l":
            return materialize[int64]()
        elif fmt == "L":
            return materialize[uint64]()
        elif fmt == "e":
            return materialize[float16]()
        elif fmt == "f":
            return materialize[float32]()
        elif fmt == "g":
            return materialize[float64]()
        elif fmt == "z":
            return materialize[binary]()
        elif fmt == "u":
            return materialize[string]()
        elif fmt == "+l":
            var field = self.children[0][].to_field()
            return list_(field.dtype.copy())
        elif fmt == "+s":
            var fields = List[Field]()
            for i in range(self.n_children):
                fields.append(self.children[i][].to_field())
            return struct_(fields)
        else:
            raise Error("Unknown format: " + fmt)

    fn to_field(self) raises -> Field:
        var name = StringSlice(unsafe_from_utf8_ptr=UnsafePointer(self.name))
        var dtype = self.to_dtype()
        var nullable = self.flags & ARROW_FLAG_NULLABLE
        return Field(String(name), dtype^, nullable != 0)

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
        writer.write(StringSlice(unsafe_from_utf8_ptr=UnsafePointer(self.name)))
        writer.write('", ')
        writer.write('format="')
        writer.write(
            StringSlice(unsafe_from_utf8_ptr=UnsafePointer(self.format))
        )
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
    var buffers: LegacyUnsafePointer[LegacyUnsafePointer[NoneType]]
    var children: LegacyUnsafePointer[LegacyUnsafePointer[CArrowArray]]
    var dictionary: LegacyUnsafePointer[CArrowArray]
    var release: LegacyUnsafePointer[CArrayReleaseFunction]
    var private_data: LegacyUnsafePointer[NoneType]

    @staticmethod
    fn from_pyarrow(pyobj: PythonObject) raises -> CArrowArray:
        var ptr = LegacyUnsafePointer[CArrowArray].alloc(1)
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
        if dtype.is_numeric() or dtype == materialize[bool_]():
            var buffer = Buffer.view(self.buffers[1], self.length, dtype.native)
            buffers.append(ArcPointer(buffer^))
        elif dtype == materialize[string]():
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
            var child_field = dtype.fields[i].copy()
            var child_array = self.children[i][].to_array(child_field.dtype)
            children.append(ArcPointer(child_array^))

        return ArrayData(
            dtype=dtype.copy(),
            length=Int(self.length),
            bitmap=bitmap,
            buffers=buffers^,
            children=children^,
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
comptime AnyFunction = fn (LegacyUnsafePointer[NoneType]) -> UInt


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
    var private_data: LegacyUnsafePointer[NoneType]


comptime get_schema_fn = fn (
    stream: LegacyUnsafePointer[CArrowArrayStreamOpaque],
    out_schema: LegacyUnsafePointer[CArrowSchema],
) -> UInt

comptime get_next_fn = fn (
    stream: LegacyUnsafePointer[CArrowArrayStreamOpaque],
    out_array: LegacyUnsafePointer[CArrowArray],
) -> UInt


@fieldwise_init
@register_passable("trivial")
struct CArrowArrayStream(Copyable, Movable):
    # Callbacks providing stream functionality
    var get_schema: get_schema_fn
    var get_next: fn (
        stream: LegacyUnsafePointer[CArrowArrayStreamOpaque],
        out_array: LegacyUnsafePointer[CArrowArray],
    ) -> UInt
    var get_last_error: fn (
        stream: LegacyUnsafePointer[CArrowArrayStreamOpaque]
    ) -> LegacyUnsafePointer[c_char]

    # Release callback
    var release: fn (
        stream: LegacyUnsafePointer[CArrowArrayStreamOpaque]
    ) -> None

    # Opaque producer-specific data
    var private_data: LegacyUnsafePointer[NoneType]


@fieldwise_init
struct ArrowArrayStream(Copyable, Movable):
    """Provide an fiendly interface to the C Arrow Array Stream."""

    var c_arrow_array_stream: LegacyUnsafePointer[CArrowArrayStreamOpaque]

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

        var alt = LegacyUnsafePointer(ptr.bitcast[CArrowArrayStreamOpaque]())
        return ArrowArrayStream(alt)

    fn c_schema(self) raises -> CArrowSchema:
        """Return the C variant of the Arrow Schema."""
        var schema = LegacyUnsafePointer[CArrowSchema].alloc(1)
        var function = LegacyUnsafePointer(
            to=self.c_arrow_array_stream[].get_schema
        ).bitcast[get_schema_fn]()[]
        var err = function(self.c_arrow_array_stream, schema)
        if err != 0:
            raise Error("Failed to get schema " + String(err))
        if not schema:
            raise Error("The schema pointer is null")
        return schema.take_pointee()

    fn c_next(self) raises -> CArrowArray:
        """Return the next buffer in the streeam."""
        var arrow_array = LegacyUnsafePointer[CArrowArray].alloc(1)
        var function = LegacyUnsafePointer(
            to=self.c_arrow_array_stream[].get_next
        ).bitcast[get_next_fn]()[]
        var err = function(self.c_arrow_array_stream, arrow_array)
        if err != 0:
            raise Error("Failed to get next arrow array " + String(err))
        if not arrow_array:
            raise Error("The arrow array pointer is null")
        return arrow_array.take_pointee()
