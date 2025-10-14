"""Test the primitive array Python API.

Over time we should implement
https://github.com/apache/arrow/blob/c6ef0fe73cc716d7949e06ca7ba4dfd0931bf10e/python/pyarrow/tests/test_array.py
"""

import pybolt as pb


def test_getitem():
    arr = pb.array([1, 2])
    assert arr.__len__() == 2
    assert arr.__getitem__(0) == 1
    assert arr.__getitem__(1) == 2
