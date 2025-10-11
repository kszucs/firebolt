from python import PythonObject, Python
from python.bindings import PythonModuleBuilder
import math
from os import abort


@export
fn PyInit_pybolt() -> PythonObject:
    try:
        var m = PythonModuleBuilder("pybolt")
        m.def_function[to_pydict](
            "to_pydict",
            docstring="Transform a firebolt structure to python dictionary.",
        )
        return m.finalize()
    except e:
        return abort[PythonObject](
            String("error creating Python Mojo module:", e)
        )


fn to_pydict(py_obj: PythonObject) raises -> PythonObject:
    """Transform a firebolt structure to a python dictionary.

    This is a dummy function used to test the infrastructure.
    """

    ref cpy = Python().cpython()
    var dict_obj = cpy.PyDict_New()
    return PythonObject(from_owned=dict_obj)
