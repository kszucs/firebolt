# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Marrow is an implementation of Apache Arrow in Mojo. Apache Arrow is a cross-language development platform for in-memory data with a standardized columnar memory format. This implementation is in early/experimental stages as Mojo itself is under heavy development.

For information about the Mojo programming language and the standard library see https://github.com/modular/modular

## Build System & Commands

This project uses **pixi** as the package manager. All commands are run through pixi:

```bash
# Run all tests
pixi run test

# Format code
pixi run fmt

# Build package
pixi run package
```

### Running Individual Tests

To run tests for a specific module:
```bash
mojo test marrow/tests/test_dtypes.mojo -I .
mojo test marrow/arrays/tests/test_primitive.mojo -I .
```

The `-I .` flag is important as it adds the current directory to the import path.

## Core Architecture

### Memory Ownership Model

The codebase follows a strict ownership hierarchy (documented in `marrow/MEMORY.md`):

1. **ArrayData** - Low-level structure that owns:
   - Data type (`dtype`)
   - Validity bitmap (`bitmap`)
   - Data buffers (`buffers`)
   - Child arrays (`children` for nested types)

2. **Typed Arrays** - High-level views that own an `ArrayData`:
   - `PrimitiveArray[T]` for numeric/boolean types
   - `StringArray` for UTF-8 strings
   - `ListArray` for nested lists
   - `StructArray` for nested structs
   - `ChunkedArray` for arrays split across multiple chunks

3. **Array Trait** - All typed arrays implement:
   - `fn take_data(deinit self) -> ArrayData` - Consumes self to create standalone ArrayData
   - `fn as_data[self_origin](ref [self_origin]self) -> UnsafePointer[ArrayData]` - Read-only reference to wrapped ArrayData

### Key Abstractions

**Buffer & Bitmap** (`marrow/buffers.mojo`):
- `Buffer` - Manages contiguous memory regions with reference counting via `ArcPointer`
- `Bitmap` - Tracks null/validity for array elements using bit-packing
- Both use 64-byte alignment for SIMD optimization

**DataType** (`marrow/dtypes.mojo`):
- Enum-based type system matching Arrow specification
- Supports primitive types (bool, int8-64, uint8-64, float32/64)
- Nested types via `list_(DataType)` and `struct_(Field, ...)`
- Uses `code` field for type identification and optional `native` field for DType mapping

**C Data Interface** (`marrow/c_data.mojo`):
- `CArrowSchema` and `CArrowArray` for zero-copy data exchange
- Primary use case: interop with PyArrow via `from_pyarrow()` and `to_pyarrow()`
- Release callbacks not yet fully implemented (Mojo limitation with C function callbacks)

### Directory Structure

```
marrow/
├── dtypes.mojo           # Type system (DataType, Field)
├── buffers.mojo          # Memory management (Buffer, Bitmap)
├── arrays/
│   ├── base.mojo         # ArrayData & Array trait
│   ├── primitive.mojo    # PrimitiveArray[T] for fixed-size types
│   ├── binary.mojo       # StringArray, BinaryArray (variable-length)
│   ├── nested.mojo       # ListArray, StructArray
│   └── chunked_array.mojo # ChunkedArray (multiple ArrayData)
|-- module                # Export functions for the python module
├── c_data.mojo           # Arrow C Data Interface
├── schema.mojo           # Schema with Fields and metadata
├── tests/                # Core module tests
└── test_fixtures/        # Shared test utilities
python/                   # The Python module top level
```

## Implementation Patterns

### Creating Arrays

```mojo
# From values (primitive)
from marrow.arrays import array
var a = array[int8](1, 2, 3, 4)

# Building incrementally (string)
var s = StringArray()
s.unsafe_append("hello")
s.unsafe_append("world")

# From PyArrow (zero-copy)
var c_array = CArrowArray.from_pyarrow(pyarrow_array)
var c_schema = CArrowSchema.from_pyarrow(pyarrow_array.type)
var dtype = c_schema.to_dtype()
var data = c_array.to_array(dtype)
```

### Null Handling

Arrays use a validity bitmap where `True` = valid, `False` = null:
- Check validity: `array.is_valid(index)` or `array.data.is_valid(index)`
- Access values: `unsafe_get(index)` (no bounds/null checking for performance)
- Set values: `unsafe_set(index, value)`

### Type Constraints

Mojo lacks dynamic dispatch, so the codebase uses:
- Compile-time parameterization (`PrimitiveArray[int64]`)
- Common `ArrayData` layout with specialized typed views
- Runtime type checking via `DataType.code` comparison

## Known Limitations

1. **Type system**: Variant elements must be copyable; references/lifetimes still evolving
2. **C callbacks**: Release callbacks in C Data Interface not called (Mojo limitation)
3. **Testing**: Relies on PyArrow for conformance testing until Mojo has JSON library
4. **Coverage**: Only bool, numeric, string, list, struct types implemented
5. **RecordBatch/Table**: Not yet implemented

## Dependencies

- Mojo `<1.0.0` (nightly builds from conda-forge and modular channels)
- PyArrow `>=19.0.1, <21` (for testing and C Data Interface validation)

## Mojo Version Notes

This codebase targets recent Mojo versions (as of Sept 2025 commits, using ~v25.7.0). Lifetime enforcement is being phased in. When working on this code:
- Use `var ^` for move semantics
- Use `deinit` for consuming parameters
- ArcPointer is used for shared ownership of buffers/bitmaps
- Many methods use `raises` for error propagation
