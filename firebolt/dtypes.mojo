# The following enum codes are copied from the C++ implementation of Arrow

# A NULL type having no physical storage
alias NA = 0

# Boolean as 1 bit, LSB bit-packed ordering
alias BOOL = 1

# Unsigned 8-bit little-endian integer
alias UINT8 = 2

# Signed 8-bit little-endian integer
alias INT8 = 3

# Unsigned 16-bit little-endian integer
alias UINT16 = 4

# Signed 16-bit little-endian integer
alias INT16 = 5

# Unsigned 32-bit little-endian integer
alias UINT32 = 6

# Signed 32-bit little-endian integer
alias INT32 = 7

# Unsigned 64-bit little-endian integer
alias UINT64 = 8

# Signed 64-bit little-endian integer
alias INT64 = 9

# 2-byte floating point value
alias FLOAT16 = 10

# 4-byte floating point value
alias FLOAT32 = 11

# 8-byte floating point value
alias FLOAT64 = 12

# UTF8 variable-length string as List<Char>
alias STRING = 13

# Variable-length bytes (no guarantee of UTF8-ness)
alias BINARY = 14

# Fixed-size binary. Each value occupies the same number of bytes
alias FIXED_SIZE_BINARY = 15

# int32_t days since the UNIX epoch
alias DATE32 = 16

# int64_t milliseconds since the UNIX epoch
alias DATE64 = 17

# Exact timestamp encoded with int64 since UNIX epoch
# Default unit millisecond
alias TIMESTAMP = 18

# Time as signed 32-bit integer, representing either seconds or
# milliseconds since midnight
alias TIME32 = 19

# Time as signed 64-bit integer, representing either microseconds or
# nanoseconds since midnight
alias TIME64 = 20

# YEAR_MONTH interval in SQL style
alias INTERVAL_MONTHS = 21

# DAY_TIME interval in SQL style
alias INTERVAL_DAY_TIME = 22

# Precision- and scale-based decimal type with 128 bits.
alias DECIMAL128 = 23

# Defined for backward-compatibility.
alias DECIMAL = DECIMAL128

# Precision- and scale-based decimal type with 256 bits.
alias DECIMAL256 = 24

# A list of some logical data type
alias LIST = 25

# Struct of logical types
alias STRUCT = 26

# Sparse unions of logical types
alias SPARSE_UNION = 27

# Dense unions of logical types
alias DENSE_UNION = 28

# Dictionary-encoded type, also called "categorical" or "factor"
# in other programming languages. Holds the dictionary value
# type but not the dictionary itself, which is part of the
# ArrayData struct
alias DICTIONARY = 29

# Map, a repeated struct logical type
alias MAP = 30

# Custom data type, implemented by user
alias EXTENSION = 31

# Fixed size list of some logical type
alias FIXED_SIZE_LIST = 32

# Measure of elapsed time in either seconds, milliseconds, microseconds
# or nanoseconds.
alias DURATION = 33

# Like STRING, but with 64-bit offsets
alias LARGE_STRING = 34

# Like BINARY, but with 64-bit offsets
alias LARGE_BINARY = 35

# Like LIST, but with 64-bit offsets
alias LARGE_LIST = 36

# Calendar interval type with three fields.
alias INTERVAL_MONTH_DAY_NANO = 37

# Run-end encoded data.
alias RUN_END_ENCODED = 38

# String (UTF8) view type with 4-byte prefix and inline small string
# optimization
alias STRING_VIEW = 39

# Bytes view type with 4-byte prefix and inline small string optimization
alias BINARY_VIEW = 40

# A list of some logical data type represented by offset and size.
alias LIST_VIEW = 41

# Like LIST_VIEW, but with 64-bit offsets and sizes
alias LARGE_LIST_VIEW = 42


struct Field(Copyable, EqualityComparable, Movable):
    var name: String
    var dtype: DataType
    var nullable: Bool

    fn __init__(
        out self, name: String, dtype: DataType, nullable: Bool = False
    ):
        self.name = name
        self.dtype = dtype
        self.nullable = nullable

    fn __eq__(self, other: Field) -> Bool:
        return (
            self.name == other.name
            and self.dtype == other.dtype
            and self.nullable == other.nullable
        )

    fn __ne__(self, other: Field) -> Bool:
        return not self == other


struct DataType(Copyable, EqualityComparable, Movable, Stringable):
    var code: UInt8
    var native: DType
    var fields: List[Field]

    fn __init__(out self, *, code: UInt8):
        self.code = code
        self.native = DType.invalid
        self.fields = List[Field]()

    fn __init__(out self, native: DType):
        if native is DType.bool:
            self.code = BOOL
        elif native is DType.int8:
            self.code = INT8
        elif native is DType.int16:
            self.code = INT16
        elif native is DType.int32:
            self.code = INT32
        elif native is DType.int64:
            self.code = INT64
        elif native is DType.uint8:
            self.code = UINT8
        elif native is DType.uint16:
            self.code = UINT16
        elif native is DType.uint32:
            self.code = UINT32
        elif native is DType.uint64:
            self.code = UINT64
        elif native is DType.float32:
            self.code = FLOAT32
        elif native is DType.float64:
            self.code = FLOAT64
        else:
            self.code = NA
        self.native = native
        self.fields = List[Field]()

    fn __init__(out self, *, code: UInt8, native: DType):
        self.code = code
        self.native = native
        self.fields = List[Field]()

    fn __init__(out self, *, code: UInt8, fields: List[Field]):
        self.code = code
        self.native = DType.invalid
        self.fields = fields

    fn __copyinit__(out self, value: Self):
        self.code = value.code
        self.native = value.native
        self.fields = value.fields

    fn __moveinit__(out self, deinit value: Self):
        self.code = value.code
        self.native = value.native
        self.fields = value.fields^

    fn __is__(self, other: DataType) -> Bool:
        return self == other

    fn __isnot__(self, other: DataType) -> Bool:
        return self != other

    fn __eq__(self, other: DataType) -> Bool:
        if self.code != other.code:
            return False
        if len(self.fields) != len(other.fields):
            return False
        for i in range(len(self.fields)):
            if self.fields[i] != other.fields[i]:
                return False
        return True

    fn __ne__(self, other: DataType) -> Bool:
        return not self == other

    fn __str__(self) -> String:
        if self.code == NA:
            return "null"
        elif self.code == BOOL:
            return "bool"
        elif self.code == INT8:
            return "int8"
        elif self.code == INT16:
            return "int16"
        elif self.code == INT32:
            return "int32"
        elif self.code == STRUCT:
            return "struct"
        else:
            return "unknown " + String(self.code)

    fn is_bool(self) -> Bool:
        return self.code == BOOL

    fn bitwidth(self) -> UInt8:
        if self.code == BOOL:
            return 1
        elif self.code == INT8:
            return 8
        elif self.code == INT16:
            return 16
        elif self.code == INT32:
            return 32
        elif self.code == INT64:
            return 64
        elif self.code == UINT8:
            return 8
        elif self.code == UINT16:
            return 16
        elif self.code == UINT32:
            return 32
        elif self.code == UINT64:
            return 64
        elif self.code == FLOAT32:
            return 32
        elif self.code == FLOAT64:
            return 64
        else:
            return 0

    @always_inline
    fn is_boolean(self) -> Bool:
        return self.code == BOOL

    @always_inline
    fn is_fixed_size(self) -> Bool:
        return self.bitwidth() > 0

    @always_inline
    fn is_integer(self) -> Bool:
        # TODO(kszucs): cannot use the following because ListLiteral.__contains__ is not implemented
        # return self.code in [INT8, INT16, INT32, INT64, UINT8, UINT16, UINT32, UINT64]
        # return self.is_signed_integer() or self.is_unsigned_integer()
        return self.is_signed_integer() or self.is_unsigned_integer()

    @always_inline
    fn is_signed_integer(self) -> Bool:
        return (
            self.code == INT8
            or self.code == INT16
            or self.code == INT32
            or self.code == INT64
        )

    @always_inline
    fn is_unsigned_integer(self) -> Bool:
        return (
            self.code == UINT8
            or self.code == UINT16
            or self.code == UINT32
            or self.code == UINT64
        )

    @always_inline
    fn is_floating_point(self) -> Bool:
        return self.code == FLOAT32 or self.code == FLOAT64

    @always_inline
    fn is_numeric(self) -> Bool:
        return self.is_integer() or self.is_floating_point()

    @always_inline
    fn is_list(self) -> Bool:
        return self.code == LIST

    @always_inline
    fn is_struct(self) -> Bool:
        return self.code == STRUCT


fn list_(value_type: DataType) -> DataType:
    return DataType(code=LIST, fields=List(Field("value", value_type)))


fn struct_(fields: List[Field]) -> DataType:
    return DataType(code=STRUCT, fields=fields)


fn struct_(*fields: Field) -> DataType:
    # TODO(kszucs): it would be easier to just List(struct_fields)
    # but that doesn't seem to be supported
    var struct_fields = List[Field](capacity=len(fields))
    for field in fields:
        struct_fields.append(field)
    return DataType(code=STRUCT, fields=struct_fields)


alias null = DataType(code=NA)
alias bool_ = DataType(code=BOOL, native=DType.bool)
alias int8 = DataType(code=INT8, native=DType.int8)
alias int16 = DataType(code=INT16, native=DType.int16)
alias int32 = DataType(code=INT32, native=DType.int32)
alias int64 = DataType(code=INT64, native=DType.int64)
alias uint8 = DataType(code=UINT8, native=DType.uint8)
alias uint16 = DataType(code=UINT16, native=DType.uint16)
alias uint32 = DataType(code=UINT32, native=DType.uint32)
alias uint64 = DataType(code=UINT64, native=DType.uint64)
alias float16 = DataType(code=FLOAT16, native=DType.float16)
alias float32 = DataType(code=FLOAT32, native=DType.float32)
alias float64 = DataType(code=FLOAT64, native=DType.float64)
alias string = DataType(code=STRING)
alias binary = DataType(code=BINARY)
