"""Python interface for dtypes."""

from python.bindings import PythonModuleBuilder
from firebolt.dtypes import DataType


def add_to_module(mut builder: PythonModuleBuilder) -> None:
    """Add DataType related data to the Python API."""

    _ = builder.add_type[DataType]("DataType")
