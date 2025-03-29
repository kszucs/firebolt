from .base import *
from .binary import *
from .nested import *
from .primitive import *


# fn array[T: DType](*values: Scalar[T]) -> PrimitiveArray[DataType(T)]:
#     var a = PrimitiveArray[DataType(T)](len(values))
#     for value in values:
#         a.unsafe_append(value)
#     return a^


fn array[T: DataType](*values: Scalar[T.native]) -> PrimitiveArray[T]:
    var a = PrimitiveArray[T](len(values))
    for value in values:
        a.unsafe_append(value)
    return a^


fn bool_array(*values: Bool) -> BoolArray:
    var a = BoolArray(len(values))
    for value in values:
        a.unsafe_append(as_bool_array_scalar(value))
    return a^
