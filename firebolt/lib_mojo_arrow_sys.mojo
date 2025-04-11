"""With the current state of Mojo and its stdlib we rely on a python C extension to get PyCapsule information.

See https://github.com/winding-lines/mojo_arrow_sys
"""
from sys.ffi import _get_global, DLHandle, os_is_macos, OpaquePointer, c_char
from python import Python
from collections.string import StringSlice
from memory import UnsafePointer
from python import PythonObject
from python.python_object import PyObjectPtr


struct LibMASys:
    var lib: DLHandle

    fn __init__(out self, path: Optional[String]):
        var real_path = path.or_else(get_libname())
        self.lib = DLHandle(real_path)

    @staticmethod
    fn destroy(mut existing):
        existing.lib.close()

    fn __copyinit__(out self, existing: Self):
        self.lib = existing.lib

    fn capsule_pointer[
        origin: MutableOrigin, //
    ](
        self,
        ref capsule: PythonObject,
        desired_capsule_type: String,
        mut out_pointer: UnsafePointer[OpaquePointer, origin=origin],
    ) -> UInt32:
        """Extract the arrow_array_stream from a python capsule by relying on a function in a couples pypi package.
        """
        var function = self.lib.get_function[
            fn (
                PyObjectPtr,
                UnsafePointer[c_char],
                UnsafePointer[OpaquePointer],
            ) -> UInt32
        ]("mos_capsule_get_pointer")

        return function(
            capsule.unsafe_as_py_object_ptr(),
            desired_capsule_type.unsafe_cstr_ptr(),
            out_pointer,
        )

    fn capsule_name(
        self,
        ref capsule: PythonObject,
    ) -> Optional[String]:
        """Extract the arrow_array_stream from a python capsule by relying on a function in a coupled pypi package.
        """
        var function = self.lib.get_function[
            fn (PyObjectPtr) -> UnsafePointer[c_char]
        ]("mos_capsule_get_name")
        var name = function(capsule.unsafe_as_py_object_ptr())
        if not name:
            print("The capsule's name is null")
            return None
        return String(name)


fn get_libname() -> String:
    """Returns the location of the library on the filesystem.

    This assumes the project has a dependency on the mojo_arrow_sys pypi package.
    """
    try:
        mas_package = Python.import_module("mojo_arrow_sys")
        return String(mas_package.__file__)
    except:
        return String("n/a mojo_arrow_sys")


fn _init_global(ignored: UnsafePointer[NoneType]) -> UnsafePointer[NoneType]:
    var ptr = UnsafePointer[LibMASys].alloc(1)
    ptr[] = LibMASys(None)

    return ptr.bitcast[NoneType]()


fn _destroy_global(the_lib: UnsafePointer[NoneType]):
    var p = the_lib.bitcast[LibMASys]()
    LibMASys.destroy(p[])
    the_lib.free()


@always_inline
fn _get_global_masys_itf() -> _MASysInterfaceImpl:
    var ptr = _get_global["libmojo_arrow_sys", _init_global, _destroy_global]()
    return _MASysInterfaceImpl(ptr.bitcast[LibMASys]())


struct _MASysInterfaceImpl:
    var _lib: UnsafePointer[LibMASys]

    fn __init__(out self, LibMASys: UnsafePointer[LibMASys]):
        self._lib = LibMASys

    fn __copyinit__(out self, existing: Self):
        self._lib = existing._lib

    fn LibMASys(self) -> LibMASys:
        return self._lib[]


fn _impl() -> LibMASys:
    return _get_global_masys_itf().LibMASys()
