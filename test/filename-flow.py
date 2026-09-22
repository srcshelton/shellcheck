#!/usr/bin/env python3
"""End-to-end SC2353 contracts; no shell source is executed by this test."""
import json
import subprocess
import sys

binary = sys.argv[1]
cases = [
    ("find . -print0 > names; cat names | sort", 1),
    ("find . -print0 > names; sort < names", 1),
    ("find . -print0 > names; sort -z < names | xargs -0 rm", 0),
    ("find . -print > names; cat names | xargs -0 rm", 1),
    ('tmp=$(mktemp); find . -print0 > "$tmp"; cat "$tmp" | sort', 1),
    ("find . -print0 > names; transform names; cat names | sort", 0),
    ("find . -print0 > names; echo text > other; cat names | sort", 0),
    ("find . -print0 > names; : > names; cat names | sort", 0),
    ("find . -print0 > names; cat names > names; cat names | sort", 0),
    ("find . -print0 > names; cd elsewhere; cat names | sort", 0),
    ('find . -print0 > "$tmp"; tmp=other; cat "$tmp" | sort', 0),
    ("if test x; then find . -print0 > names; fi; cat names | sort", 0),
    ("if test x; then find . -print0 > names; else find . -print0 > names; fi; cat names | sort", 1),
    ("names=$(find . -print0)", 1),
    ("names=$(find . -print)", 1),
    ("names=`find . -print0`", 1),
    ("names=$(printf '%s' text)", 0),
    ('names=$(find . -print0 | transform); printf "%s" "$names"', 0),
    ("find . -print0 | while read name; do :; done", 1),
    ("find . -print | while IFS= read -r name; do :; done", 1),
    ('find . -print0 | while IFS= read -r -d "" name; do printf "%s\\0" "$name"; done | sort', 1),
    ('find . -print0 | while IFS= read -r -d "" name; do printf "%s\\0" "$name"; done | sort -z', 0),
    ('find . -print0 | while IFS= read -r -d "" name; do copy=$name; printf "%s\\n" "$copy"; done | sort', 1),
    ('find . -print0 | while IFS= read -r -d "" name; do name=text; printf "%s\\n" "$name"; done | sort', 0),
    ("cat <(find . -print0) | sort", 1),
    ("sort < <(find . -print0)", 1),
    ("sort -z < <(find . -print0)", 0),
    ("find . -print0 > names; sort names", 1),
    ("find . -print0 > names; sort -z names | xargs -0 rm", 0),
    ("find . -print0 > names; uniq names", 1),
    ("find . -print0 | sort -z > names; cat names | sort", 1),
    ('find . -print0 | while IFS= read -r -d "" name; do printf "%s\\\\n" "$name"; done > names; sort names', 1),
    ("produce() { find . -print0; }; produce | sort", 1),
    ("filter() { sort; }; find . -print0 | filter", 1),
    ("filter() { sort -z; }; find . -print0 | filter | xargs -0 rm", 0),
    ("produce() { echo heading; find . -print0; }; produce | sort", 0),
    ("produce() { produce; }; produce | sort", 0),
    ("produce() { find . -print0; }; produce() { echo x; }; produce | sort", 0),
    ("produce | sort; produce() { find . -print0; }", 0),
    ("produce() { find . -print0; }; eval code; produce | sort", 0),
    ("find . -print0 | unknown | sort", 0),
    ("consume() { cat; sort; }; find . -print0 | consume", 0),
    ("consume() { :; sort; }; find . -print0 | consume", 1),
    ("names=$(exit; find . -print0)", 0),
    ("produce() { return; find . -print0; }; produce | sort", 0),
    ('IFS=; find . -print0 | while read -r -d "" name; do :; done', 0),
    ('find . -print0 | while IFS= read -d "" name; do :; done', 1),
    ('find . -print0 | while read -r -d "" name; do :; done', 1),
    ('find . -print0 | while IFS= read -r -d "" name; do printf "%s\\0" $name; done | sort', 0),
    ('for name in *.txt; do printf "%s\\n" "$name"; done | sort', 1),
    ('for name in *.txt; do printf "%s\\0" "$name"; done | sort -z', 0),
    ('for name in *.txt; do dirname "$name"; done | sort', 1),
    ('for name in *.txt; do dirname -z "$name"; done | sort -z', 0),
    ('find . -print0 > names; printf "%s" "$(rewrite names)"; cat names | sort', 0),
    ("find . -print0 > names; cat names >> names; cat names | sort", 0),
    ("produce() { find . -print0; }; unset -f produce; produce | sort", 0),
    ("filter() { sort; }; filter", 0),
    ("produce() { find . -print0; }; names=$(produce)", 1),
    ("produce() { find . -print0; }; consume() { sort; }; produce | consume", 1),
    ('show() { printf "%s\\\\n" "$1"; }; find . -print0 | while IFS= read -r -d "" name; do show "$name"; done | sort', 1),
]
count = 0
for source, expected in cases:
    for enabled in (False, True):
        args = ["--enable=check-filename-streams"] if enabled else []
        result = subprocess.run(
            [binary, "--norc", "-s", "bash", "-f", "json1",
             "--include=SC2353", *args, "-"],
            input=source, text=True, capture_output=True)
        comments = json.loads(result.stdout)["comments"]
        want = expected if enabled else 0
        assert not result.stderr and result.returncode == bool(want), (source, result)
        assert len(comments) == want, (source, comments)
        assert all(c["level"] == "warning" and c["fix"] is None for c in comments)
        count += 1
for shell in ("sh", "bash", "dash", "busybox", "ksh", "irix-sh", "irix-ksh", "irix-bsh", "irix-jsh"):
    for source in ("find . -print0 > names; sort < names", "names=\u0060find . -print0\u0060"):
        for control, expected in (("", 1), ("disable=SC2353", 0)):
            result = subprocess.run(
                [binary, "--norc", "-s", shell, "-f", "json1", "--include=SC2353", "-"],
                input="# shellcheck enable=check-filename-streams " + control + "\n" + source,
                text=True, capture_output=True)
            assert not result.stderr and result.returncode == bool(expected), result
            assert len(json.loads(result.stdout)["comments"]) == expected, result
            count += 1
result = subprocess.run(
    [binary, "--norc", "-s", "bash", "-f", "json1", "--include=SC2353",
     "--enable=check-filename-streams", "--severity=error", "-"],
    input="names=$(find . -print0)", text=True, capture_output=True)
assert result.returncode == 0 and not result.stderr and json.loads(result.stdout)["comments"] == []
count += 1
print(f"PASS {count} filename-flow CLI contracts")
