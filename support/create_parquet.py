"""Create a parquet file for testing."""

import os
import pyarrow as pa
from pyarrow import parquet

def create_test_table() -> pa.Table:
    """Create a test table with various data types for testing."""

    # Primitive types
    int_values = pa.array([1, 2, 3, 4, 5], type=pa.int32())
    float_values = pa.array([1.1, 2.2, 3.3, 4.4, 5.5], type=pa.float32())
    str_values = pa.array(["one", "two", "three", "four", "five"])
    bool_values = pa.array([True, False, True, False, True])

    # Lists of primitives
    list_int_values = pa.array([[1, 2], [3, 4, 5], [], [6], [7, 8, 9, 10]])
    list_float_values = pa.array([[1.1, 2.2], [3.3], [4.4, 5.5, 6.6], [], [7.7]])
    list_str_values = pa.array([["a", "b"], ["c"], [], ["d", "e"], ["f", "g", "h"]])

    # Struct type
    struct_type = pa.struct([("field_a", pa.int32()), ("field_b", pa.string())])
    struct_values = pa.array(
        [
            {"field_a": 1, "field_b": "foo"},
            {"field_a": 2, "field_b": "bar"},
            {"field_a": 3, "field_b": "baz"},
            {"field_a": 4, "field_b": "qux"},
            {"field_a": 5, "field_b": "quux"},
        ],
        type=struct_type,
    )

    # List of structs
    list_struct_type = pa.list_(struct_type)
    list_struct_values = pa.array(
        [
            [{"field_a": 1, "field_b": "foo"}, {"field_a": 2, "field_b": "bar"}],
            [{"field_a": 3, "field_b": "baz"}],
            [],
            [
                {"field_a": 4, "field_b": "qux"},
                {"field_a": 5, "field_b": "quux"},
                {"field_a": 6, "field_b": "corge"},
            ],
            [{"field_a": 7, "field_b": "grault"}],
        ],
        type=list_struct_type,
    )

    # Create table
    table = pa.table(
        {
            "int_col": int_values,
            "float_col": float_values,
            "str_col": str_values,
            "bool_col": bool_values,
            "list_int_col": list_int_values,
            "list_float_col": list_float_values,
            "list_str_col": list_str_values,
            "struct_col": struct_values,
            "list_struct_col": list_struct_values,
        }
    )
def create_test_parquet(output_path="test_data.parquet"):
    """Create a parquet file with various data types for testing."""
    table = create_test_table()

    # Write to parquet file
    parquet.write_table(table, output_path)
    print(f"Created parquet file at: {output_path}")

    return output_path


if __name__ == "__main__":
    # Ensure the directory exists
    os.makedirs("test_data", exist_ok=True)

    # Create the test file in the test_data directory
    create_test_parquet("test_data/test_file.parquet")
