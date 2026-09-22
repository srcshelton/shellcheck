# Diagnostic additions

These changes do not require changes to `# shellcheck` directive syntax.
The two policy checks below are opt-in, including for IRIX profiles. Existing
checks, severity filtering and disable directives continue to apply normally.

## SC2118 and SC2155 corrections

SC2118 now explains Ksh's coprocess meaning of `|&`, rather than incorrectly
saying the operator is unsupported. This does not add generic Ksh coprocess
parsing or change the separate native-validated IRIX parser.

SC2155 also detects command substitutions nested inside parameter expansion
words, such as `declare value=${fallback:-$(command)}`. It keeps the existing
readonly-local exemption. Process substitutions are not treated as command
substitution statuses. Multiple substitutions in one assignment produce one
diagnostic; separate declaration and assignment remain the remedy.

## SC2350: literal single quotes in parameter words

For example, `"${value:-'default'}"` includes the apostrophes in the value.
The warning covers default, assignment and alternate-value operators, not
pattern-removal operators or error-message words. It does not cross command
substitution boundaries or warn about a deliberately double-quoted word
containing apostrophes. There is no automatic fix: removing characters may
change an intentional value, and nested quoting differs on IRIX.

## SC2351: require-variable-declarations

Enable with `--enable=require-variable-declarations` or
`# shellcheck enable=require-variable-declarations`.

This is a **strict lexical policy**, not proof of an unset variable, a runtime
declaration-order analysis, or a requirement to enable `set -u`. An ordinary
assignment is a use, not an explicit declaration. Reads of optional/defaulted
variables also count. Use an appropriate explicit declaration before the first
read/write, e.g. `export value`, or `local value` inside a Bash function.

Recognized declarations are shell-specific: export/readonly everywhere;
local/declare/typeset in Bash; typeset in Ksh and IRIX sh/ksh; local in dash
and BusyBox. Existing ShellCheck-known environment/shell variables and special
parameters are exempt. Only static variable names represented by the variable
flow are covered; dynamic names and arbitrary eval strings are not resolved.

Declarations are seen in source traversal order, including conditional
branches. They are not a guarantee that a declaration executes on every path.
Functions inherit declarations visible at their definition; their declarations
do not leak to sibling functions or the outer script. Subshells also isolate
declarations. Put shared declarations above function definitions for this
policy. Declarations in parsed sourced files can be seen, but unparsed external
files and runtime callers are not inferred. At most one notice per undeclared
name per lexical scope is emitted. There is no automatic insertion of local,
export or readonly, because each would change semantics.

## SC2352: check-function-tracing-status

Enable with `--enable=check-function-tracing-status` or its enable directive.
The check offers informational advice when a uniquely named function ends in
`set +x`, `set -x` or their xtrace equivalents after another simple command,
and the function is directly used as a condition. The status being tested is
the tracing command's, not the preceding operation's. Save that status before
the toggle and return it explicitly if that is the intended contract.

Only status-preserving wrapper/group paths connect a call to a test; a later
command in a group or a background call does not qualify. Known redefinitions
of `set` are excluded as well.

This is not a claim that the function is wrong, that every builtin masks a
failure, or that adding `set -e` repairs it. No automatic rewrite is supplied.
Explicit returns, guarded compound commands, functions containing only the
toggle, non-tracing set operations, multiple definitions, and calls whose
status is hidden by a pipeline/command substitution are outside this check.

## SC2353: check-filename-streams

An opt-in, pipeline-local analysis tracks whether known filename-producing
commands emit NUL or newline records. It checks the expectations of subsequent
supported stages, not just whether a pipeline contains `-0` somewhere.

For example, `find . -print0 | xargs -0 dirname | sort` loses the NUL convention
when ordinary dirname writes its output. The warning points at sort, where
the ambiguous newline filename stream is processed. Newline-separated names
cannot represent an embedded newline unambiguously. The check also catches
`find . -print0 | xargs command` and the reverse mismatch.

Supported models include find's default print, -print, -print0, selected exact
filename-only -printf formats and -exec grep filename output; grep -l/-L with
file operands; record-filtering grep; sort; uniq; plain cat; and xargs invoking
dirname/basename. Predicate operands are distinguished from find actions.
Known GNU-style NUL flags are modelled, including dirname/basename -z. A
legacy SC2038 warning is not duplicated for the same simple find/xargs pair.

Known shell-function overrides, unknown commands/options, mixed find output
modes, redirections and stderr
pipes break tracking. Numeric find output, grep counts, independent file input,
and unknown xargs child output are not assumed to carry filename records.
One report stops the affected stream to avoid cascades. No warning means
only that no supported unsafe connection was established, NOT that arbitrary
filenames are proved safe throughout the program.

This does not yet track streams through variables, temporary files, functions,
read loops or command substitutions. Nor does selecting an IRIX shell imply
that installed utilities support GNU NUL options. Advice is capability-neutral
and has no automatic rewrite. Existing defaults and other checks are unchanged.
