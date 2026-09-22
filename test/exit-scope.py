#!/usr/bin/env python3
"""Opt-in EXIT lifetime coverage and default SC2349 regression contracts."""
import json
import subprocess
import sys

binary = sys.argv[1]
count = 0
def check(shell, source, expected, enabled=True, code=2354, extra=()):
    global count
    options = ["--enable=check-exit-trap-scope"] if enabled else []
    result = subprocess.run(
        [binary, "--norc", "-s", shell, "-f", "json1", "--include=SC"+str(code),
         *options, *extra, "-"], input=source, text=True, capture_output=True)
    assert not result.stderr and result.returncode == bool(expected), (shell, source, result)
    comments = json.loads(result.stdout)["comments"]
    assert len(comments) == expected, (shell, source, comments)
    assert all(c["level"] == "warning" and c["fix"] is None for c in comments)
    count += 1

for shell in ("bash", "dash", "irix-sh", "irix-ksh"):
    declaration = "typeset" if shell.startswith("irix") else "local"
    head = "f() { " + declaration + " value=inner; "
    action = """trap 'echo "$value"' 0; """
    good = head + action + "}; f"
    check(shell, good, 1)
    check(shell, good, 0, enabled=False)
    check(shell, good, 0, extra=("--severity=error",))
    check(shell, good, 1, extra=("--enable=all",))
    check(shell, "# shellcheck disable=SC2354\n" + good, 0)
    check(shell, head + action + "return 0; }; f", 1)
    check(shell, head + action + ":; }; f", 1)
    check(shell, head + action + "};", 0)
    check(shell, head + action + "}; command f", 0)
    check(shell, "f; " + head + action + "};", 0)
    check(shell, head + action + "exit 1; }; f", 0)
    check(shell, "set -e; " + head + action + "false; }; f", 0)
    check(shell, head + action + "trap - 0; }; f", 0)
    check(shell, head + action + """trap 'echo replacement' 0; }; f""", 0)
    check(shell, head + action + "}; f; trap - 0", 0)
    check(shell, head + action + "}; f; trap \"$dynamic\" 0", 0)
    check(shell, head + action + "}; f; exec other", 0)
    check(shell, head + action + "}; f; builtin trap - 0", 0)
    check(shell, head + """trap "echo $value" 0; }; f""", 0)
    check(shell, head + """trap 'value=fresh; echo "$value"' 0; }; f""", 0)
    check(shell, head + action + "unset value; }; f", 0)
    check(shell, head + action + "if test x; then trap - 0; fi; }; f", 0)
    check(shell, head + action + "}; ( f )", 0)
    check(shell, head + action + "}; f() { :; }; f", 0)
    check(shell, "trap() { :; }; " + good, 0)
    check(shell, head + "trap \"$dynamic\" 0; }; f", 0)
    check(shell, head + action + "eval code; }; f", 0)
    check(shell, """cleanup() { echo "$value"; }; """ + head + "trap cleanup 0; }; f", 1)
    check(shell, """cleanup() { value=fresh; echo "$value"; }; """ + head + "trap cleanup 0; }; f", 0)
    deep = "g() { h; }; h() { exit 1; }; " + head + action + "g; }; f"
    check(shell, deep, 1 if shell.startswith("irix") else 0)
    check(shell, deep, 0, enabled=False)
    check(shell, "g() { trap - 0; exit; }; " + head + action + "g; }; f", 0)
    check(shell, "g() { g; }; " + head + action + "g; }; f", 0)
    check(shell, "true() { trap - 0; }; g() { true; exit; }; " + head + action + "g; }; f", 0)
    check(shell, "g() { : \"${action:=unknown}\"; exit; }; " + head + action + "g; }; f", 0)
    check(shell, "g() { exit 1 2; }; " + head + action + "g; }; f", 0)
    check(shell, "g() { exit \"$status\"; }; " + head + action + "g; }; f", 0)
    check(shell, "g() { :; true; exit 2; }; " + head + action + "g; }; f",
          1 if shell.startswith("irix") else 0)
    chain = " ".join(f"g{i}() {{ g{i+1}; }};" for i in range(8))
    check(shell, chain + " g8() { exit; }; " + head + action + "g0; }; f", 0)
    check(shell, "return() { trap - 0; }; " + head + action + "return; }; f", 0)
    check(shell, good, 0, extra=("--extended-analysis=false",))
    check(shell, "# shellcheck enable=check-exit-trap-scope\n" + good, 1, enabled=False)
    check(shell, head + action + "g; }; f; g() { exit; }", 0)
    # The existing default check remains unchanged and is not duplicated.
    check(shell, head + action + "exit 1; }; f",
          1 if shell.startswith("irix") else 0, enabled=False, code=2349)
for shell in ("sh", "busybox", "ksh", "irix-dtksh", "irix-bsh", "irix-jsh"):
    check(shell, """f() { local value=inner; trap 'echo "$value"' 0; }; f""", 0)
print(f"PASS {count} EXIT-scope CLI contracts")
