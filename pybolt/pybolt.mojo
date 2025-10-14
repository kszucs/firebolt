from python import PythonObject, Python
from python.bindings import PythonModuleBuilder
import math
from firebolt.module.dtypes_api import add_to_module as add_dtypes
from firebolt.module.arrays.primitive_api import add_to_module as add_primitive
from os import abort


@export
fn PyInit_pybolt() -> PythonObject:
    try:
        var m = PythonModuleBuilder("pybolt")
        add_dtypes(m)
        add_primitive(m)
        return m.finalize()
    except e:
        return abort[PythonObject](
            String("error creating Python Mojo module:", e)
        )
