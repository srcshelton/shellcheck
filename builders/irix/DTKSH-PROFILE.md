# IRIX CDE dtksh profile evidence

`irix-dtksh` models the executable shipped by SGI's August 2006 IRIX 6.5
Complementary Applications media as product `Common Desktop Environment,
5.3.5`, subsystem `cde.sw.eoe`. Its IDB entry is:

```
f 0555 root sys usr/dt/bin/dtksh src/cde1/dtksh/dtksh cde.sw.eoe sum(10700) size(850124) off(6556663) needrqs cmpsize(518909)
```

The unpacked executable has SHA-256
`f5263c7a63cbab758da9e6acef406910b2460c9d7476654f274b38282e863996`
and contains `Version M-12/28/93d`, matching the ksh93 core in the Open Group
CDE 2.1.30 source import. The tardist provides the executable and its CDE
runtime/support files, not source code; `src/cde1/dtksh/dtksh` records SGI's
build-tree input pathname. The public CDE source is therefore corroborating
source for the language core, not a claim of byte-identical SGI 5.3.5 source.

The package executable was copied with its matching `libXm`, `libDtSvc`,
`libDtWidget`, and `libDtHelp` libraries, requickstarted only in a disposable
directory, and exercised on IRIX 6.5.30. The native matrix established:

| Accepted | Rejected or different |
| --- | --- |
| `${.sh.version}`, `[[...]]`, extglob | `[[... =~ ...]]` |
| `((...))`, `$((...))`, `base#digits` | C-style hexadecimal constants |
| replacement and substring expansions | process substitution, here-strings |
| indexed/associative arrays and namerefs | `typeset -C` compound variables |
| floating variables and ANSI-C quoting | brace sequences and `pipefail` |
| `function f` or `f()` separately | combined `function f()` form |
| case `;&`, `printf %q` | newer ksh93-only additions above |

The final pipeline component runs in the current shell. `read` accepts
`[-Aprs]`, `-d`, `-t`, and `-u`; `set -o` does not list `pipefail`. With
`set -e`, a failing command inside `$(...)` terminates the substitution and
the enclosing assignment returns failure, confirming inherited errexit.

Source tests cover aliases/directives/shebangs, CLI precedence, supported and
unsupported constructs, read flags, arithmetic constants, function syntax,
and pipeline scope. `test-dtksh-profile` is the compiled CLI contract. The
native build gate also exercises `irix-dtksh` alongside `irix-sh` and
`irix-ksh`. A 24-file SGI package corpus selected the profile automatically
from `/usr/dt/bin/dtksh` shebangs and produced output identical to an explicit
`--shell=irix-dtksh` run. Supplying the packaged `DtFuncs.dtsh` through the
extracted sysroot removed both missing-source observations.
