# IRIX Bourne-shell profile evidence

`irix-bsh` and `irix-jsh` select the same static language model. On the
qualified IRIX 6.5.30 Fuel, /bin/bsh and /bin/jsh resolve to /sbin/bsh:
419948 bytes, POSIX checksum 847508902. The installed bsh(1) manual identifies
jsh as the job-control invocation of that shell. Native $- is `s` for bsh
and `ms` for jsh under -c; without a controlling terminal both reject jobs/fg.
No claim of interactive terminal/job-control qualification is made.

The 2026-09-21 native matrix established:

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

Fourteen focused cases passed in both shells through -c, stdin and standalone
files (84 native status/output contracts). A further 24 contracts verify that
-nt/-ot/-ef are rejected and -k is accepted in both shells and all three modes.
Broader read-only native probes
cover builtins/options and contrast /sbin/sh and /bin/ksh. Source tests cover
selection, shebangs, file extensions, supported/unsupported syntax, pipeline
scope and advice; existing dialect tests remain required.
