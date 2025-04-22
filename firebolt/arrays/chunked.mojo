"""Implements a ChunkedArray class for handling pyarrow.Array-like objects."""

from firebolt.buffers import Buffer, Bitmap
from firebolt.dtypes import DataType, DType


struct ChunkedArray:
    """An array-like composed from a (possibly empty) collection of pyarrow.Arrays.

    [Reference](https://arrow.apache.org/docs/python/generated/pyarrow.ChunkedArray.html#pyarrow-chunkedarray).
    """

    var dtype: DataType
    var length: Int
    var chunks: List[ArrayData]

    fn _compute_lenght(mut self) -> None:
        """Update the length of the array from the length of its chunks."""
        var length = 0
        for chunk in self.chunks:
            length += chunk.length
        self.length = length

    fn __init__(out self, dtype: DataType, chunks: List[ArrayData]):
        self.dtype = dtype
        self.chunks = chunks
        self.length = 0
        self._compute_lenght()

    fn chunk(self, index: Int) -> ref [self.chunks] ArrayData:
        """Returns the chunk at the given index.

        Args:
          index: The desired index.

        Returns:
          A reference to the chunk at the given index.
        """
        return self.chunks[index]

    fn combine_chunks(self) -> ArrayData:
        """Combines all chunks into a single array."""
        var bitmap = ArcPointer(Bitmap.alloc(self.length))
        var combined = ArrayData(
            dtype=self.dtype,
            length=self.length,
            bitmap=bitmap,
            buffers=List[ArcPointer[Buffer]](),
            children=List[ArcPointer[ArrayData]](),
        )
        var start = 0
        for chunk in self.chunks:
            combined.bitmap[].extend(chunk.bitmap[], start, chunk.length)
            start += chunk.length
            combined.buffers.extend(chunk.buffers)
            combined.children.extend(chunk.children)
        return combined

    fn drop_nulls[T: DType](mut self) -> None:
        """Drops null values from the chunked array."""
        for ref chunk in self.chunks:
            chunk.drop_nulls[T]()

        self._compute_lenght()

    fn null_count(self) -> Int:
        """Returns the number of null values in the chunked array."""
        var count = 0
        for chunk in self.chunks:
            count += chunk.null_count()
        return count
