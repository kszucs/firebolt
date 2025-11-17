from marrow.arrays import BoolArray


fn as_bool_array_scalar(value: Bool) -> BoolArray.scalar:
    """Bool conversion function."""
    return BoolArray.scalar(Scalar[DType.bool](value))


fn bool_array(*values: Bool) -> BoolArray:
    var a = BoolArray(len(values))
    for value in values:
        a.unsafe_append(as_bool_array_scalar(value))
    return a^
