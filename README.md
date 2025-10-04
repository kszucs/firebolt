# In-progress implementation of Apache Arrow in Mojo

Initial motivation for this project was to learn the Mojo programming language and the best is to learn by doing. Since I've been involved in the Apache Arrow project for a while, I thought it would be a good idea to implement the Arrow specification in Mojo.

The implementation is far from being complete or usable in practice, but I prefer to share it its early stage so others can join the effort.

### What is Arrow?

[Apache Arrow](https://arrow.apache.org) is a cross-language development platform for in-memory data. It specifies a standardized language-independent columnar memory format for flat and hierarchical data, organized for efficient analytic operations on modern hardware like CPUs and GPUs.

### What is Mojo?

[Mojo](https://www.modular.com/mojo) is promising new programming language built on top of MLIR providing the expressiveness of Python, with the performance of systems programming languages.

### Why Arrow in Mojo?

I find the Mojo language really promising and Arrow should be a first-class citizen in Mojo's ecosystem. Since the language itself is still in its early stages, under heavy development, this Arrow implementation is still in an experimental phase.

## Currently implemented abstractions

- `Buffer` providing the memory management for contiguous memory regions.
- `DataType` for defining the `Arrow` data types.
- `ArrayData` as the common layout for all `Arrow` arrays.
- Typed array views for primitive, string and nested arrow arrays providing more convenient and efficient access to the underlying `ArrayData`.
- [Arrow C Data Interface](https://arrow.apache.org/docs/format/CDataInterface.html) to exchange arrow data between other implementations in a zero-copy manner, but only one direction is implemented for now.

## Examples

### Creating a primitive array

```mojo
from firebolt.arrays import array, StringArray, ListArray, Int64Array
from firebolt.dtypes import int8, bool_, list_

var a = array[int8](1, 2, 3, 4)
var b = array[bool_](True, False, True)
```

### Creating a string array

```mojo
var s = StringArray()
s.unsafe_append("hello")
s.unsafe_append("world")
```

More convenient APIs are planned to be added in the future.

### Creating a list array

```mojo
var ints = Int64Array()
var lists = ListArray(ints)

ints.append(1)
ints.append(2)
ints.append(3)
lists.unsafe_append(True)
assert_equal(len(lists), 1)
assert_equal(lists.data.dtype, list_(int64))
```

### Formatting arrays for display

```mojo
from firebolt.io import Formatter
from firebolt.arrays import array
from firebolt.dtypes import int32

var arr = array[int32](1, 2, 3, 4, 5, 6, 7, 8, 9, 10)
var output = String()
var formatter = Formatter(limit=3)  # Show first 3 elements
formatter.format(output, arr)
print(output)
# Output: PrimitiveArray[DataType(code=int32)]([1, 2, 3, ...])
```

The formatter supports all array types including nested structures like lists and structs, and automatically handles NULL values.

### Zero-copy access of a PyArrow array in Mojo

For more details see the [Arrow C Data Interface](https://arrow.apache.org/docs/format/CDataInterface.html).

```mojo
var pa = Python.import_module("pyarrow")
var pyarr = pa.array(
   [1, 2, 3, 4, 5], mask=[False, False, False, False, True]
)

var c_array = CArrowArray.from_pyarrow(pyarr)
var c_schema = CArrowSchema.from_pyarrow(pyarr.type)

var dtype = c_schema.to_dtype()
assert_equal(dtype, int64)
assert_equal(c_array.length, 5)
assert_equal(c_array.null_count, 1)
assert_equal(c_array.offset, 0)
assert_equal(c_array.n_buffers, 2)
assert_equal(c_array.n_children, 0)

var data = c_array.to_array(dtype)
var array = data.as_int64()
assert_equal(array.bitmap[].size, 64)
assert_equal(array.is_valid(0), True)
assert_equal(array.is_valid(1), True)
assert_equal(array.is_valid(2), True)
assert_equal(array.is_valid(3), True)
assert_equal(array.is_valid(4), False)
assert_equal(array.unsafe_get(0), 1)
assert_equal(array.unsafe_get(1), 2)
assert_equal(array.unsafe_get(2), 3)
assert_equal(array.unsafe_get(3), 4)
assert_equal(array.unsafe_get(4), 0)

array.unsafe_set(0, 10)
assert_equal(array.unsafe_get(0), 10)
assert_equal(str(pyarr), "[\n  10,\n  2,\n  3,\n  4,\n  null\n]")
```

## Rough edges and limitations

So far the implementation has been focused to provide a solid foundation for further development, not for memory efficiency, performance or completeness.

A couple of notable limitations:

1. The chosen abstractions may not be ideal, but:
   - mojo lacks support for dynamic dispatch at the moment
   - variant elements must be copyable
   - references and lifetimes are not hardened yet
   - expressing nested data types is not straightforward

   Due to these reasons polymorphism is achieved by defining a common layout for type hierarchies and providing specialized views for each child type. This approach seems to work well for nested `DataType` and `Array` types and the implementation can be continued while `Mojo` gains the necessary features to rethink theses abstractions.

2. The `C Data Interface` doesn't call the release callbacks yet and only consuming arrow data is implemented for now because a `Mojo` callback cannot be passed to a `C` function yet. As mojo matures, this limitation will be certainly addressed.

3. Testing of the conformance against the `Arrow` specification is done by reading arrow data from the python implementation `PyArrow` since `Mojo` can already call python functions. If the project manages to evolve further, it should be wired into the arrow integration testing suite, but first that requires a `JSON` library in `Mojo`.

4. Only boolean, numeric, string, list and struct datatypes are supported for now since these cover most of the implementation complexity. Support for the rest of the arrow data types can be added incrementally.

5. A convenient API hasn't been designed yet, preferably that should be tackled once the implementation is more mature.

6. No `ChunkedArray`s, `RecordBatch`es, `Table`s are implemented yet, but soon they will be.

## Development

I shared the implementation it its current state so others can join the effort.
If the project manages to evolve, ideally it should be donated to the upstream Apache Arrow project.

Please install pixi by following the instructions in the [documentation](https://pixi.sh/latest/installation/).
The tests can be run with:

```bash
pixi run test

```bash

## References

- [Another effort to implement Arrow in Mojo](https://github.com/mojo-data/arrow.mojo)
