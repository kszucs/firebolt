Starting with the Sept 2025 version of Mojo the compiler is starting to enforce
[lifetimes](https://docs.modular.com/mojo/manual/values/lifetimes/). This document proposes an approach at using memory.

1. Low level memory format

Apache Arrow defines a columnar memory [format](https://arrow.apache.org/docs/format/Columnar.html) that can
be accessed in many languages, including Python. Firebolt defines
an API to access this format in Mojo. One of the goals is to allow high performance
integration between Python and Mojo when it comes to process vast amounts of data.

1. ArrayData owns the data

In Firebolt ArrayData is the low level API that will access the Arrow memory block.

As such it should own the data type, bitmap, buffers and children.

2. Typed arrays own ArrayData

The next level in the API are the typed arrays: PrimitiveArray, ListArray, StructArray and so on.

When constructing a typed array from an ArrowData the typed array will own the ArrayData. 

The typed arrays provide convenient accessors into the ArrayData. For example PrimitiveArray
provides a `bitmap` and a `buffer`. Since Mojo doesn't currently provide properties these 
helper accessors will be implemented as functions.

3. The Array trait

All of the typed Arrays are expected to implement the Array trait by providing 2 methods:

- `fn take_data(deinit self) -> ArrayData` creates a standalone ArrayData by destroying the self.
- `fn data(self) -> ref [self] ArrayData` access a read only copy of the ArrayGata in the typed array.
