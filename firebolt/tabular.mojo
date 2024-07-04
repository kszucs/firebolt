from .arrays import *


struct RecordBatch:
    var schema: Schema
    var fields: List[Array]

    fn __init__(inout self, schema: Schema, fields: List[Array]):
        self.schema = schema
        self.fields = fields
