"""Build test fixtures for Firebolt."""

from python import Python, PythonObject


def build_list_of_list_of_ints(pa: PythonObject) -> PythonObject:
    """Build a PyArrow arrow with a list of list of ints.

    Note: nested ListLiterals are not supported as of Apr 2025.
    """
    var values = Python.list()
    values.append([1, 2])
    values.append([3, 4, 5])
    values.append([])
    values.append([6])
    return pa.array(values)


fn _add_struct_entry(
    array_def: PythonObject, field_a: Int, field_b: StringSlice
) raises -> None:
    var entry = Python.dict()
    entry["field_a"] = field_a
    entry["field_b"] = field_b
    array_def.append(entry)


def build_struct(pa: PythonObject) -> PythonObject:
    """Build a PyArrow array with a struct.

    Note: dictionary literals are not supported as of Apr 2025.
    """
    var struct_def = Python.list()
    struct_def.append(("field_a", pa.int32()))
    struct_def.append(("field_b", pa.string()))
    var struct_type = pa.`struct`(struct_def)

    var array_def = Python.list()

    _add_struct_entry(array_def, 1, "foo")
    _add_struct_entry(array_def, 2, "bar")
    _add_struct_entry(array_def, 3, "baz")
    _add_struct_entry(array_def, 4, "qux")

    return pa.array(array_def, type=struct_type)
