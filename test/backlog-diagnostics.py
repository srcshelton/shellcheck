#!/usr/bin/env python3
"""CLI contracts for the five diagnostic backlog enhancements (stdin only)."""
import json
import subprocess
import sys

binary = sys.argv[1]
count = 0


def check(source, code, expected, shell="bash", *options):
    global count
    result = subprocess.run(
        [binary, "--norc", "--format=json1", "--shell=" + shell,
         "--include=SC" + str(code), *options, "-"],
        input=source, text=True, capture_output=True, check=False)
    assert not result.stderr, (source, result.stderr)
    assert result.returncode == (1 if expected else 0), (source, result)
    comments = json.loads(result.stdout)["comments"]
    assert len(comments) == expected, (source, comments)
    assert all(c["code"] == code for c in comments), comments
    count += 1
    return comments


for shell in ("sh", "bash", "dash", "busybox", "ksh", "irix-sh",
              "irix-ksh", "irix-dtksh", "irix-bsh", "irix-jsh"):
    source = 'printf "%s\\n" "${value:-\'default\'}"'
    comments = check(source, 2350, 1, shell)
    assert comments[0]["level"] == "warning" and comments[0]["fix"] is None
    check('# shellcheck disable=SC2350\n' + source, 2350, 0, shell)
    check('printf "%s\\n" ${value:-\'default\'}', 2350, 0, shell)
    check('printf "%s\\n" "${value#\'prefix\'}"', 2350, 0, shell)
    check(source, 2350, 0, shell, "--severity=error")

    source = 'value=1; printf "%s\\n" "$value"'
    check(source, 2351, 0, shell)
    check(source, 2351, 1, shell, "--enable=require-variable-declarations")
    check('export value; ' + source, 2351, 0, shell,
          "--enable=require-variable-declarations")
    check('# shellcheck enable=require-variable-declarations\n' + source,
          2351, 1, shell)
    check('# shellcheck enable=require-variable-declarations disable=SC2351\n' + source,
          2351, 0, shell)

    source = 'f() { false; set +x; }; if f; then :; fi'
    check(source, 2352, 0, shell)
    comments = check(source, 2352, 1, shell, "--enable=check-function-tracing-status")
    assert comments[0]["level"] == "info" and comments[0]["fix"] is None
    check('# shellcheck enable=check-function-tracing-status disable=SC2352\n' + source,
          2352, 0, shell)
    check('f() { false; set +x; }; f', 2352, 0, shell,
          "--enable=check-function-tracing-status")
    check('f() { false; status=$?; set +x; return "$status"; }; if f; then :; fi',
          2352, 0, shell, "--enable=check-function-tracing-status")
    check('f() { false; set +x; }; if { f; true; }; then :; fi',
          2352, 0, shell, "--enable=check-function-tracing-status")
    check('f() { false; set +x; }; if { :; f; }; then :; fi',
          2352, 1, shell, "--enable=check-function-tracing-status")

for shell in ("bash", "ksh", "irix-sh", "irix-ksh", "irix-dtksh"):
    source = 'typeset value="${a:-`false`}${b:-`false`}"'
    check(source, 2155, 1, shell)
    check('# shellcheck disable=SC2155\n' + source, 2155, 0, shell)
    check('typeset value; value="${a:-`false`}"', 2155, 0, shell)

message = check('foo |& bar', 2118, 1, "ksh")[0]["message"]
assert "coprocess" in message and "does not support" not in message
check('foo |& bar', 2118, 0, "bash")
check('f() { local -r value=${a:-$(false)}; }', 2155, 0)
check('declare value=${a:-<(false)}', 2155, 0)
print(f"PASS {count} backlog diagnostic CLI contracts")
