#!/usr/bin/env python3
"""Compiled CLI boundaries for opt-in filename-stream analysis."""
import json
import subprocess
import sys

binary = sys.argv[1]
cases = [
    ("find . -print0 | sort", 1),
    ("find . -print0 | sort -z | uniq -z | xargs -0 rm", 0),
    ("find . -print0 | xargs -0 dirname | sort | uniq", 1),
    ("find . -print0 | xargs -0 dirname -z | sort -z | uniq -z", 0),
    ("find . -print0 | xargs rm", 1),
    ("find . -print | xargs -0 rm", 1),
    ("find . | xargs rm", 0),  # Existing SC2038 owns this simple case.
    ("find . -exec grep -Fl needle {} + | xargs -0 dirname", 1),
    ("find . -exec grep -FlZ needle {} + | xargs -0 dirname -z | sort -z", 0),
    ("find . -name -print0 -print | xargs -0 rm", 1),
    ("find . -name -print -print0 | xargs -0 rm", 0),
    ("find . -printf '%s\\n' | sort", 0),
    ("find . -printf '%p\\0' | sort", 1),
    ("grep -lZ needle *.txt | sort", 1),
    ("printf data | grep -lZ data | sort", 0),
    ("find . -print0 | grep -zv cache | sort -z", 0),
    ("find . -print0 | grep -v cache | xargs -0 rm", 1),
    ("find . -print0 | arbitrary-transform | sort", 0),
    ("find . -print0 | sort --unknown", 0),
    ("find . -print0 >names | sort", 0),
    ("find . -print0 | sort <names", 0),
    ("find . -print0 | sort -o result", 0),
    ("find . -print0 | cat other | sort", 0),
    ("find . -print0 | cat - | sort", 1),
    ("printf '%s\\n' data | xargs -0 dirname | sort", 0),
    ("sort() { cat; }; find . -print0 | sort", 0),
]
count = 0
for shell in ("sh", "bash", "ksh", "irix-sh", "irix-ksh", "irix-dtksh", "irix-bsh", "irix-jsh"):
    for source, expected in cases:
        for enabled in (False, True):
            options = ["--enable=check-filename-streams"] if enabled else []
            result = subprocess.run([binary, "--norc", "-s", shell, "-f", "json1",
                                     "--include=SC2353", *options, "-"],
                                    input=source, text=True, capture_output=True)
            actual = json.loads(result.stdout)["comments"]
            want = expected if enabled else 0
            assert result.returncode == bool(want) and not result.stderr, result
            assert len(actual) == want, (shell, source, actual)
            assert all(c["code"] == 2353 and c["level"] == "warning"
                       and c["fix"] is None for c in actual)
            count += 1

for directive in ("enable=check-filename-streams", "enable=check-filename-streams disable=SC2353"):
    result = subprocess.run([binary, "--norc", "-s", "sh", "-f", "json1", "--include=SC2353", "-"],
                            input="# shellcheck " + directive + "\nfind . -print0 | sort",
                            text=True, capture_output=True)
    expected = 0 if "disable" in directive else 1
    assert result.returncode == expected and not result.stderr, result
    assert len(json.loads(result.stdout)["comments"]) == expected
    count += 1
print(f"PASS {count} filename-stream CLI contracts")
