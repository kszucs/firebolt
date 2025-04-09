from .arrays import *


struct RecordBatch:
    var schema: Schema
    var fields: List[Array]

    fn __init__(inoutself, schema: Schema, fields: List[Array]):
        self.schema = schema
        self.fields = fields
