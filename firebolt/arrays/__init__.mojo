from .base import *
from .binary import *
from .nested import *
from .primitive import *


fn array[T: DataType](*values: Scalar[T.native]) -> PrimitiveArray[T]:
    """Create a primitive array with the given values."""
    var a = PrimitiveArray[T](len(values))
    for value in values:
        a.unsafe_append(value)
    return a^
