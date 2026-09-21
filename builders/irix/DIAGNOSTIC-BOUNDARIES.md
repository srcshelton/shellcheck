# Diagnostic scope and limits

These checks do not modify shell scripts, their execution, or the shared
CFG/DFA transfer rules. They change findings deliberately; no static analyzer can promise zero regressions
for all possible shell programs.

## SC2030 / SC2031: separate local bindings

The legacy subshell-assignment check now distinguishes a function's explicitly
declared local from globals and from locals in other functions with the same
spelling. Only this check requests the additional function boundaries; all
other variable-flow consumers retain their existing stream.

Real writes lost across a subshell still warn. Bare redeclaration of an existing
local does not erase a lost write. Explicit global declarations and export
retain global behaviour. This is a correction to lexical bookkeeping, not a
new interprocedural model of dynamically scoped calls.

## SC2218: terminating forward-call branches

The existing postdominator check is retained. An additional conservative rule
covers a reachable top-level call before an unconditional same-source function
definition, including an error branch that exits before reaching the definition.
This diagnoses the previously missed `_usage` call in `mpivis`.

The additional rule declines status probes, calls inside functions, common
external/builtin names and known possible earlier definitions (including
definitions found in sourced files). Its warning deliberately says that the
call precedes the definition and qualifies the advice with "if this call
should use it". Dynamic source/eval or external commands can supply an earlier
binding: this is not a claim to prove command-not-found. This distinction is
necessary for the real `mpivis`, whose preceding configuration loader uses
eval. The existing stronger postdominator message/level and the earlier
old-fgl unreachable-node repair remain unchanged.

## SC2349: IRIX EXIT action reads a departing local

For `irix-sh` and `irix-ksh`, warn at an explicit function-local `exit` when a
definite local declaration and a statically established EXIT/0 action overlap:
the delayed action may read an outer or unset value after the local disappears.
This follows the retained native IRIX 6.5.30 file/stdin/command-string tests.

The check accounts for literal actions and available, uniquely defined cleanup
helpers, including bounded transitive calls; assignments in those actions or
helpers; trap replacement/removal; and conditional paths. An inherited global
trap is considered only with proven direct top-level calling contexts.
It declines dynamic actions/commands, source/eval, ambiguous definitions,
recursive helpers, explicit unset within the action/helper, scope-changing
subshells and uncertain trap state. Helper
reads not reachable from the action are excluded. Disabling extended analysis
also disables this proof. Natural script termination, implicit errexit and
arbitrary call chains remain outside its deliberately bounded coverage.

The message describes a scope risk, not a guarantee that cleanup is wrong.
If reading the outer value is intentional, use an ordinary documented
`# shellcheck disable=SC2349` on the exit. Prefer explicit cleanup before exit
or deliberately persistent state where that matches the program's intent.
There is no autofix: double-quoting a trap can change expansion timing and
semantics. No warning is generalized to Bash or IRIX's older bsh/jsh language.

Regression coverage includes positive/negative source matrices in Analytics,
`test-deferred-diagnostics`, `test-native-exit-trap-scope` (60 native contracts),
and the existing full property and profile suites.
Broader before/after host diagnostic comparisons are regression evidence, not
native MIPSpro compiler qualification.
