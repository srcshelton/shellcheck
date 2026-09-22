#!/usr/bin/env python3
"""Real GNU-utility semantics, run in Linux with a caller-owned scratch parent.

Creates/removes only its TemporaryDirectory child. This is not a ShellCheck
test substitute: it verifies the delimiter assumptions used by the CLI tests.
"""
from pathlib import Path
import subprocess
import sys
import tempfile

with tempfile.TemporaryDirectory(prefix="filename-records-", dir=sys.argv[1]) as directory:
    root = Path(directory)
    names = ["has space", "line\nbreak", "quote'and\\backslash"]
    for name in names:
        path = root / name
        path.mkdir()
        (path / "input.txt").write_text("needle\n")

    def run(pipeline):
        return subprocess.check_output(["bash", "-o", "pipefail", "-c", pipeline], cwd=root)

    expected = b"".join(name + b"\0" for name in sorted(("./" + n).encode() for n in names))
    good = run("find . -type f -print0 | xargs -0 dirname -z | LC_ALL=C sort -zu")
    assert good == expected, (good, expected)
    bad = run("find . -type f -print0 | xargs -0 dirname | LC_ALL=C sort -u")
    assert len(bad.splitlines()) != len(names), bad
    grep_good = run("find . -type f -exec grep -FlZ needle {} + | xargs -0 dirname -z | LC_ALL=C sort -zu")
    assert grep_good == expected
    # Show that a delimiter mismatch is real, even without xargs or deletion.
    bad_sort = run("find . -type f -print0 | LC_ALL=C sort")
    assert bad_sort != run("find . -type f -print0 | LC_ALL=C sort -z")
print("PASS 4 real GNU filename-delimiter contracts; private scratch removed")
