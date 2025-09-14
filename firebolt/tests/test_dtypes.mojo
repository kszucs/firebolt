from testing import assert_equal, assert_true, assert_false
import firebolt.dtypes as dt


def test_bool_type():
    assert_true(dt.bool_ == dt.bool_)
    assert_false(dt.bool_ == dt.int64)
    assert_true(dt.bool_ is dt.bool_)
    assert_false(dt.bool_ is dt.int64)


def test_list_type():
    assert_true(dt.list_(dt.int64) == dt.list_(dt.int64))
    assert_false(dt.list_(dt.int64) == dt.list_(dt.int32))


def test_field():
    var field = dt.Field("a", dt.int64, False)
    var writer = String()
    writer.write(field)
    var expected = (
        'Field(name="a", dtype=DataType(code=int64), nullable=False, )'
    )
    assert_equal(writer, expected)
    assert_equal(String(field), expected)
    assert_equal(field.__repr__(), expected)


def test_struct_type():
    s1 = dt.struct_(
        dt.Field("a", dt.int64, False), dt.Field("b", dt.int32, False)
    )
    s2 = dt.struct_(
        dt.Field("a", dt.int64, False), dt.Field("b", dt.int32, False)
    )
    s3 = dt.struct_(
        dt.Field("a", dt.int64, False),
        dt.Field("b", dt.int32, False),
        dt.Field("c", dt.int8, False),
    )
    assert_true(s1 == s2)
    assert_false(s1 == s3)


def test_is_integer():
    assert_true(dt.int8.is_integer())
    assert_true(dt.int16.is_integer())
    assert_true(dt.int32.is_integer())
    assert_true(dt.int64.is_integer())
    assert_true(dt.uint8.is_integer())
    assert_true(dt.uint16.is_integer())
    assert_true(dt.uint32.is_integer())
    assert_true(dt.uint64.is_integer())
    assert_false(dt.bool_.is_integer())
    assert_false(dt.float32.is_integer())
    assert_false(dt.float64.is_integer())
    assert_false(dt.list_(dt.int64).is_integer())


def test_is_signed_integer():
    assert_true(dt.int8.is_signed_integer())
    assert_true(dt.int16.is_signed_integer())
    assert_true(dt.int32.is_signed_integer())
    assert_true(dt.int64.is_signed_integer())
    assert_false(dt.uint8.is_signed_integer())
    assert_false(dt.uint16.is_signed_integer())
    assert_false(dt.uint32.is_signed_integer())
    assert_false(dt.uint64.is_signed_integer())
    assert_false(dt.bool_.is_signed_integer())
    assert_false(dt.float32.is_signed_integer())
    assert_false(dt.float64.is_signed_integer())


def test_is_unsigned_integer():
    assert_false(dt.int8.is_unsigned_integer())
    assert_false(dt.int16.is_unsigned_integer())
    assert_false(dt.int32.is_unsigned_integer())
    assert_false(dt.int64.is_unsigned_integer())
    assert_true(dt.uint8.is_unsigned_integer())
    assert_true(dt.uint16.is_unsigned_integer())
    assert_true(dt.uint32.is_unsigned_integer())
    assert_true(dt.uint64.is_unsigned_integer())
    assert_false(dt.bool_.is_unsigned_integer())
    assert_false(dt.float32.is_unsigned_integer())
    assert_false(dt.float64.is_unsigned_integer())


def test_is_floating_point():
    assert_false(dt.int8.is_floating_point())
    assert_false(dt.int16.is_floating_point())
    assert_false(dt.int32.is_floating_point())
    assert_false(dt.int64.is_floating_point())
    assert_false(dt.uint8.is_floating_point())
    assert_false(dt.uint16.is_floating_point())
    assert_false(dt.uint32.is_floating_point())
    assert_false(dt.uint64.is_floating_point())
    assert_false(dt.bool_.is_floating_point())
    assert_true(dt.float32.is_floating_point())
    assert_true(dt.float64.is_floating_point())


def test_bitwidth():
    assert_equal(dt.int8.bitwidth(), 8)
    assert_equal(dt.int16.bitwidth(), 16)
    assert_equal(dt.int32.bitwidth(), 32)
    assert_equal(dt.int64.bitwidth(), 64)
    assert_equal(dt.uint8.bitwidth(), 8)
    assert_equal(dt.uint16.bitwidth(), 16)
    assert_equal(dt.uint32.bitwidth(), 32)
    assert_equal(dt.uint64.bitwidth(), 64)
    assert_equal(dt.bool_.bitwidth(), 1)
    assert_equal(dt.float32.bitwidth(), 32)
    assert_equal(dt.float64.bitwidth(), 64)
    assert_equal(dt.list_(dt.int64).bitwidth(), 0)
