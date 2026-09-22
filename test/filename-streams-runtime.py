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
    files = run("find . -name input.txt -print0 | LC_ALL=C sort -z")
    saved = run("find . -name input.txt -print0 > list; cat list | LC_ALL=C sort -z")
    assert saved == files
    loop = run('find . -name input.txt -print0 | while IFS= read -r -d "" name; do copy=$name; printf "%s\\0" "$copy"; done | LC_ALL=C sort -z')
    assert loop == files
    wrapper = run('produce() { find . -name input.txt -print0; }; consume() { LC_ALL=C sort -z; }; produce | consume')
    assert wrapper == files
    process = run("LC_ALL=C sort -z < <(find . -name input.txt -print0)")
    assert process == files
    captured = run('names=$(find . -name input.txt -print0); printf "%s" "$names"')
    assert b"\0" not in captured and captured != files
    reencoded = run('find . -name input.txt -print0 | while IFS= read -r -d "" name; do printf "%s\\n" "$name"; done')
    assert len(reencoded.splitlines()) > len(names)
print("PASS 10 real GNU filename-delimiter contracts; private scratch removed")
