"""Test the schema.mojo file."""
from testing import assert_equal, assert_true
from python import Python, PythonObject
from firebolt.schema import Schema
from firebolt.dtypes import (
    int8,
    int16,
    int32,
    int64,
    uint8,
    uint16,
    uint32,
    uint64,
)
from firebolt.dtypes import float16, float32, float64, binary, string, list_
from firebolt.c_data import Field, CArrowSchema


def test_schema_primitive_fields():
    """Test the schema with primitive fields."""

    # Create a schema with different data types
    fields = List[Field](
        Field("field1", int8, False),
        Field("field2", int16, False),
        Field("field3", int32, False),
        Field("field4", int64, False),
        Field("field5", uint8, False),
        Field("field6", uint16, False),
        Field("field7", uint32, False),
        Field("field8", uint64, False),
        Field("field9", float16, False),
        Field("field10", float32, False),
        Field("field11", float64, False),
        Field("field12", binary, False),
        Field("field13", string, False),
    )
    var nb_fields = len(fields)

    var schema = Schema(fields=fields^)

    # Check the number of fields in the schema
    assert_equal(len(schema.fields), nb_fields)

    # Check the names of the fields in the schema
    for i in range(nb_fields):
        assert_equal(schema.field(index=i).name, "field" + String(i + 1))


def test_schema_names() -> None:
    fields = List[Field](
        Field("field1", int8, False),
        Field("field2", int16, False),
    )

    var schema = Schema(fields=fields^)
    assert_equal(
        schema.names(),
        List[String](["field{}".format(i + 1) for i in range(2)]),
    )

    schema.append(Field("field3", int32))
    assert_equal(
        schema.names(),
        List[String](["field{}".format(i + 1) for i in range(3)]),
    )


def test_from_c_schema() -> None:
    var pa = Python.import_module("pyarrow")
    var pa_schema = pa.schema(
        Python.list(
            pa.field("field1", pa.list_(pa.int32())),
            pa.field(
                "field2",
                pa.`struct`(
                    Python.list(
                        pa.field("field_a", pa.int32()),
                        pa.field("field_b", pa.float64()),
                    )
                ),
            ),
        )
    )

    var c_schema = CArrowSchema.from_pyarrow(pa_schema)
    var schema = Schema.from_c(c_schema)

    assert_equal(len(schema.fields), 2)

    # Test first field.
    ref field_0 = schema.field(index=0)
    assert_true(field_0.dtype.is_list())
    assert_true(field_0.dtype.fields[0].dtype.is_integer())

    # Test second field.
    ref field_1 = schema.field(index=1)
    assert_true(field_1.dtype.is_struct())
    assert_equal(field_1.dtype.fields[0].name, "field_a")
    assert_equal(field_1.dtype.fields[1].name, "field_b")
