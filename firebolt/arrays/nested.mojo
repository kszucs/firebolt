from memory import ArcPointer
from ..buffers import Buffer, Bitmap
from ..dtypes import *


struct ListArray(Array):
    var data: ArrayData
    var bitmap: ArcPointer[Bitmap]
    var offsets: ArcPointer[Buffer]
    var values: ArcPointer[ArrayData]
    var capacity: Int

    fn __init__(out self, data: ArrayData) raises:
        if not data.dtype.is_list():
            raise Error("Unexpected dtype")
        elif len(data.buffers) != 1:
            raise Error("ListArray requires exactly one buffer")
        elif len(data.children) != 1:
            raise Error("ListArray requires exactly one child array")

        self.data = data
        self.bitmap = data.bitmap
        self.offsets = data.buffers[0]
        self.values = data.children[0]
        self.capacity = data.length

    fn __init__[T: Array](out self, var values: T, capacity: Int = 1):
        """Initialize a list with the given values.

        Default capacity is at least 1 to accomodate the values.

        Args:
            values: Array to use as the first element in the ListArray.
            capacity: The capacity of the ListArray.
        """
        var values_data = values.as_data()
        var list_dtype = list_(values_data.dtype)

        var bitmap = Bitmap.alloc(capacity)
        bitmap.unsafe_set(0, True)
        var offsets = Buffer.alloc[DType.uint32](capacity + 1)
        offsets.unsafe_set[DType.uint32](0, 0)
        offsets.unsafe_set[DType.uint32](1, values_data.length)

        self.capacity = capacity
        self.bitmap = ArcPointer(bitmap^)
        self.offsets = ArcPointer(offsets^)
        self.values = ArcPointer(values_data^)
        self.data = ArrayData(
            dtype=list_dtype,
            length=1,
            bitmap=self.bitmap,
            buffers=List(self.offsets),
            children=List(self.values),
            offset=0,
        )

    fn __moveinit__(out self, deinit existing: Self):
        self.data = existing.data^
        self.bitmap = existing.bitmap^
        self.offsets = existing.offsets^
        self.values = existing.values^
        self.capacity = existing.capacity

    fn __len__(self) -> Int:
        return self.data.length

    fn as_data(self) -> ArrayData:
        return self.data

    fn is_valid(self, index: Int) -> Bool:
        return self.bitmap[].unsafe_get(index)

    fn unsafe_append(mut self, is_valid: Bool):
        self.bitmap[].unsafe_set(self.data.length, is_valid)
        self.offsets[].unsafe_set[DType.uint32](
            self.data.length + 1, self.values[].length
        )
        self.data.length += 1

    fn unsafe_get(self, index: Int) raises -> ArrayData:
        """Access the value at a given index in the list array."""
        var child_dtype = self.data.dtype.fields[0].dtype
        if not child_dtype.is_numeric():
            raise Error(
                "Only numeric dtype supported right now, got {}".format(
                    child_dtype
                )
            )
        var start = Int(self.offsets[].unsafe_get[DType.int32](index))
        var end = Int(self.offsets[].unsafe_get[DType.int32](index + 1))
        ref first_child = self.data.children[0][]
        return ArrayData(
            dtype=child_dtype,
            bitmap=first_child.bitmap,
            buffers=first_child.buffers,
            offset=self.data.offset + start,
            length=end - start,
            children=List[ArcPointer[ArrayData]](),
        )

    fn write_to[W: Writer](self, mut writer: W):
        """
        Formats this ListArray to the provided Writer.

        Parameters:
            W: A type conforming to the Writable trait.

        Args:
            writer: The object to write to.
        """

        writer.write("ListArray(")
        writer.write("length=")
        writer.write(self.data.length)
        writer.write(")")

    fn __str__(self) -> String:
        return String.write(self)

    fn __repr__(self) -> String:
        return String.write(self)


struct StructArray(Array):
    var data: ArrayData
    var bitmap: ArcPointer[Bitmap]
    var fields: List[Field]
    var capacity: Int

    fn __init__(
        out self,
        var fields: List[Field],
        capacity: Int = 0,
    ):
        var bitmap = Bitmap.alloc(capacity)
        bitmap.unsafe_range_set(0, capacity, True)

        var struct_dtype = struct_(fields)

        self.capacity = capacity
        self.bitmap = ArcPointer(bitmap^)
        self.fields = fields^
        self.data = ArrayData(
            dtype=struct_dtype,
            length=0,
            bitmap=self.bitmap,
            buffers=List[ArcPointer[Buffer]](),
            children=List[ArcPointer[ArrayData]](),
            offset=0,
        )

    fn __moveinit__(out self, deinit existing: Self):
        self.data = existing.data^
        self.bitmap = existing.bitmap^
        self.fields = existing.fields^
        self.capacity = existing.capacity

    fn __len__(self) -> Int:
        return self.data.length

    fn as_data(self) -> ArrayData:
        return self.data

    fn write_to[W: Writer](self, mut writer: W):
        """
        Formats this StructArray to the provided Writer.

        Parameters:
            W: A type conforming to the Writable trait.

        Args:
            writer: The object to write to.
        """

        writer.write("StructArray(")
        writer.write("length=")
        writer.write(self.data.length)
        writer.write(")")

    fn __str__(self) -> String:
        return String.write(self)

    fn __repr__(self) -> String:
        return String.write(self)
