"""Python interface for primitive array."""

from os import abort
from python.bindings import PythonModuleBuilder, PythonObject
from marrow.dtypes import DataType
from marrow.arrays.base import ArrayData
from marrow.arrays import primitive
from python import Python


@fieldwise_init
struct PrimitiveArray(Movable, Representable):
    """Type erased PrimitiveArray so that we can return to python."""

    var data: ArrayData
    var offset: Int
    var capacity: Int

    fn __repr__(self) -> String:
        return "PrimitiveArray"

    @staticmethod
    fn __len__(self_ptr: UnsafePointer[Self]) -> PythonObject:
        """Return the length of the underlying ArrayData."""
        return self_ptr[].data.length

    @staticmethod
    fn __getitem__(
        self_ptr: UnsafePointer[Self], index: PythonObject
    ) raises -> PythonObject:
        """Access the element at the given index."""

        return primitive.Int64Array(self_ptr[].data.copy()).unsafe_get(
            Int(index)
        )


fn array(content: PythonObject) raises -> PythonObject:
    """Create a primitive array, only In64 implemented so far.

    Args:
        content: An iterable of Ints.

    Returns:
        A PrimitiveArray wrapped in a PythonObject.

    """
    var actual = primitive.Int64Array()

    var iter = content.__iter__()
    while iter.__has_next__():
        var next = iter.__next__()
        var value = Int(next)
        actual.append(value)

    var result = PrimitiveArray(
        data=actual.data.copy(),
        offset=actual.offset,
        capacity=actual.capacity,
    )
    return PythonObject(alloc=result^)


def add_to_module(mut builder: PythonModuleBuilder) -> None:
    """Add primitive array support to the python API."""

    _ = (
        builder.add_type[PrimitiveArray]("PrimitiveArray")
        .def_method[PrimitiveArray.__len__]("__len__")
        .def_method[PrimitiveArray.__getitem__]("__getitem__")
    )
    builder.def_function[array](
        "array",
        docstring="Build a primitive array with the given data and datatype",
    )
