# IRIX Bourne-shell profiles

`irix-bsh` and `irix-jsh` select the same static language model for IRIX's
older Bourne shell. Select one with `shellcheck --shell=irix-bsh script.sh`
or `--shell=irix-jsh`; recognised bsh/jsh shebangs select it automatically.

On the tested IRIX 6.5.30 installation, `/bin/bsh` and `/bin/jsh` resolve to
`/sbin/bsh`. The bsh(1) manual identifies jsh as its job-control invocation.
Job control still requires an appropriate terminal; the profile does not
validate interactive terminal behaviour.

The supported language differs from modern POSIX sh:

| Accepted | Unsupported or different |
| --- | --- |
| backticks, ordinary functions, brace-form case | $(...), $((...)), ((...)), function keyword |
| default/assignment/alternate parameter words | parameter length and prefix/suffix removal |
| plain read; separate assignment then export/readonly | read -r; export/readonly name=value |
| dynamic unary test operator, traditional test flags | test -e/-S/-nt/-ot/-ef, [[...]], ! pipeline negation |
| external expr and printf, echo -n | let, typeset, print, command, ANSI-C quoting |
| inherited errexit in command substitutions | pipefail and set -o |

Pipeline components run in subshells; assigning through the last component
does not update the parent. IRIX utility conventions remain separate from the
Korn-language extensions of irix-sh/irix-ksh. The parser accepts the shared
IRIX brace-case/else-if/test conventions without enabling Korn coprocesses.
Advice must not replace backticks/read/expr with unsupported POSIX features.

These boundaries were checked through command strings, stdin and standalone
files on IRIX 6.5.30. Other IRIX versions should be checked against their own
shells. In particular, `test -k` is accepted, while `-nt`, `-ot` and `-ef` are not.

From a Git checkout, run `python3 builders/irix/test-bourne-profiles SHELLCHECK`
against your compiled binary for selection, syntax and diagnostic contracts.
The [manual](../../shellcheck.1.md) describes profile selection and the separate
`irix-sh`, `irix-ksh` and `irix-dtksh` profiles.
