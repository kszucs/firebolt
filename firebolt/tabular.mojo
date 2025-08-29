from .arrays import *
from .schema import Schema


@fieldwise_init
struct RecordBatch:
    var schema: Schema
    var fields: List[ArrayData]
