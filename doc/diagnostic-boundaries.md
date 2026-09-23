# Diagnostic scope and limitations

These checks analyse shell source without executing or modifying it. The
following boundaries explain when a diagnostic applies and when the analysis
declines to infer runtime behaviour. Silence is not proof that a script is safe.

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
For example, an error branch can call a usage function and exit before the
function's definition is reached.

The additional rule declines status probes, calls inside functions, common
external/builtin names and known possible earlier definitions (including
definitions found in sourced files). Its warning deliberately says that the
call precedes the definition and qualifies the advice with "if this call
should use it". Dynamic source/eval or external commands can supply an earlier
binding: this is not a claim to prove command-not-found. The existing stronger
postdominator message/level and the
old-fgl unreachable-node repair remain unchanged.

## SC2349: IRIX EXIT action reads a departing local

For `irix-sh` and `irix-ksh`, warn at an explicit function-local `exit` when a
definite local declaration and a statically established EXIT/0 action overlap:
the delayed action may read an outer or unset value after the local disappears.
This follows native IRIX 6.5.30 file/stdin/command-string behaviour.

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

The separate opt-in SC2354 now covers bounded ordinary-function return and
proven nested explicit-exit calls; see [additional checks](additional-checks.md). Native
IRIX sh/ksh tests show that implicit errexit retains the local value in the
tested cases even though explicit exit loses it. SC2349 has therefore NOT
been generalized to implicit failures, and neither new case changes profile
defaults or shared flow analysis.

The message describes a scope risk, not a guarantee that cleanup is wrong.
If reading the outer value is intentional, use an ordinary documented
`# shellcheck disable=SC2349` on the exit. Prefer explicit cleanup before exit
or deliberately persistent state where that matches the program's intent.
There is no autofix: double-quoting a trap can change expansion timing and
semantics. No warning is generalized to Bash or IRIX's older bsh/jsh language.

Regression coverage includes positive/negative source matrices in Analytics,
[CLI contracts](../builders/irix/test-deferred-diagnostics),
[native EXIT/local tests](../builders/irix/test-native-exit-trap-scope), and
the existing property and profile suites. Runtime tests require a private
writable output directory and an unprivileged IRIX account, not a specific
username. The language checks are distinct from qualifying a compiler build.
