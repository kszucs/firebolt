struct Box[T: CollectionElement](CollectionElement):
    var ptr: UnsafePointer[T]

    fn __init__(inoutself, owned value: T):
        self.ptr = UnsafePointer[T].alloc(1)
        self.ptr.init_pointee_move(value)

    fn __copyinit__(inoutself, value: Self):
        self.ptr = UnsafePointer[T].alloc(1)
        self.ptr.init_pointee_copy(value.ptr[])

    fn __moveinit__(inoutself, owned value: Self):
        self.ptr = value.ptr

    fn __getitem__(ref [_]self: Self) -> ref [__lifetime_of(self)] T:
        return self.ptr[]
