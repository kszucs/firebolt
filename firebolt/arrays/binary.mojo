from memory import ArcPointer, memcpy
from collections.string import StringSlice
from ..buffers import Buffer
from ..dtypes import *


struct StringArray(Array):
    var data: ArrayData
    var capacity: Int

    fn __init__(out self, var data: ArrayData) raises:
        if data.dtype != string:
            raise Error(
                "Unexpected dtype '{}' instead of 'string'.".format(data.dtype)
            )
        elif len(data.buffers) != 2:
            raise Error("StringArray requires exactly two buffers")

        self.capacity = data.length
        self.data = data^

    fn bitmap(self) -> ref [self.data.bitmap] ArcPointer[Bitmap]:
        return self.data.bitmap

    fn offsets(self) -> ref [self.data.buffers] ArcPointer[Buffer]:
        return self.data.buffers[0]

    fn values(self) -> ref [self.data.buffers] ArcPointer[Buffer]:
        return self.data.buffers[1]

    fn __init__(out self, capacity: Int = 0):
        var bitmap = Bitmap.alloc(capacity)
        # TODO(kszucs): initial values capacity should be either 0 or some value received from the user
        var values = Buffer.alloc[DType.uint8](capacity)
        var offsets = Buffer.alloc[DType.uint32](capacity + 1)
        offsets.unsafe_set[DType.uint32](0, 0)

        self.capacity = capacity
        self.data = ArrayData(
            dtype=string,
            length=0,
            bitmap=ArcPointer(bitmap^),
            buffers=List(ArcPointer(offsets^), ArcPointer(values^)),
            children=List[ArcPointer[ArrayData]](),
            offset=0,
        )

    fn __moveinit__(out self, deinit existing: Self):
        self.data = existing.data^
        self.capacity = existing.capacity

    fn __len__(self) -> Int:
        return self.data.length

    fn as_data[
        self_origin: ImmutableOrigin
    ](ref [self_origin]self) -> UnsafePointer[ArrayData, mut=False]:
        return UnsafePointer(to=self.data)

    fn take_data(deinit self) -> ArrayData:
        return self.data^

    fn grow(mut self, capacity: Int):
        self.bitmap()[].grow(capacity)
        self.offsets()[].grow[DType.uint32](capacity + 1)
        self.capacity = capacity

    # fn shrink_to_fit(out self):

    fn is_valid(self, index: Int) -> Bool:
        return self.bitmap()[].unsafe_get(index)

    fn unsafe_append(mut self, value: String):
        # todo(kszucs): use unsafe set
        var index = self.data.length
        var last_offset = self.offsets()[].unsafe_get[DType.uint32](index)
        var next_offset = last_offset + len(value)
        self.data.length += 1
        self.bitmap()[].unsafe_set(index, True)
        self.offsets()[].unsafe_set[DType.uint32](index + 1, next_offset)
        self.values()[].grow[DType.uint8](next_offset)
        var dst_address = self.values()[].get_ptr_at(Int(last_offset))
        var src_address = value.unsafe_ptr()
        memcpy(dst_address, src_address, len(value))

    fn unsafe_get(self, index: UInt) -> StringSlice[__origin_of(self)]:
        var start_offset = self.offsets()[].unsafe_get[DType.uint32](
            index + self.data.offset
        )
        var end_offset = self.offsets()[].unsafe_get[DType.uint32](
            index + 1 + self.data.offset
        )
        var address = self.values()[].get_ptr_at(Int(start_offset))
        var length = UInt(Int(end_offset - start_offset))
        return StringSlice[__origin_of(self)](ptr=address, length=length)

    fn unsafe_set(mut self, index: Int, value: String) raises:
        var start_offset = self.offsets()[].unsafe_get[DType.int32](index)
        var end_offset = self.offsets()[].unsafe_get[DType.int32](index + 1)
        var length = Int(end_offset - start_offset)

        if length != len(value):
            raise Error(
                "String length mismatch, inplace update must have the same"
                " length"
            )

        var dst_address = self.values()[].get_ptr_at(Int(start_offset))
        var src_address = value.unsafe_ptr()
        memcpy(dst_address, src_address, length)

    fn write_to[W: Writer](self, mut writer: W):
        """
        Formats this StringArray to the provided Writer.

        Parameters:
            W: A type conforming to the Writable trait.

        Args:
            writer: The object to write to.
        """

        writer.write("StringArray( length=")
        writer.write(self.data.length)
        writer.write(", data= [")
        for i in range(self.data.length):
            writer.write('"')
            writer.write(self.unsafe_get((i)))
            writer.write('", ')
            if i > 1:
                break
        writer.write(" ])")

    fn __str__(self) -> String:
        return String.write(self)

    fn __repr__(self) -> String:
        return String.write(self)
