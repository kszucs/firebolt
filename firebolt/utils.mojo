struct Box[T: CollectionElement](CollectionElement):
    var ptr: UnsafePointer[T]

    fn __init__(inout self, owned value: T):
        self.ptr = UnsafePointer[T].alloc(1)
        self.ptr.init_pointee_move(value)

    fn __copyinit__(inout self, value: Self):
        self.ptr = UnsafePointer[T].alloc(1)
        self.ptr.init_pointee_copy(value.ptr[])

    fn __moveinit__(inout self, owned value: Self):
        self.ptr = value.ptr

    fn __getitem__(ref [_]self: Self) -> ref [__lifetime_of(self)] T:
        return self.ptr[]
