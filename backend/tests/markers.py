"""xfail markers that document known defects / missing features.

Both are strict: when a bug is fixed (or a feature is built) the test XPASSes,
which fails the run and tells you to delete the marker.
"""
import pytest


def bug(bug_id: str, msg: str):
    return pytest.mark.xfail(strict=True, reason=f"{bug_id}: {msg}")


def missing(msg: str):
    return pytest.mark.xfail(strict=True, reason=f"NOT IMPLEMENTED: {msg}")
