# Fork corrections and enhancements

This index describes changes implemented in this fork, not a claim that an
upstream issue is closed or that every case is solved. See [CHANGELOG.md](CHANGELOG.md)
for released versus unreleased changes. Optional checks require explicit
enablement unless a shell profile documents otherwise.

## Upstream issue coverage

| Issue | Change / commit subject |
| --- | --- |
| [#2367](https://github.com/koalaman/shellcheck/issues/2367) | `Add opt-in unused suppression notices (#2367)`; `Enable IRIX safety checks by default (#2367)`; `Preserve suppressions for disabled optional checks (#2367)` |
| [#753](https://github.com/koalaman/shellcheck/issues/753) | `Add opt-in house style checks (#753, #3511)` |
| [#3511](https://github.com/koalaman/shellcheck/issues/3511) | `Add opt-in house style checks (#753, #3511)` |
| [#3149](https://github.com/koalaman/shellcheck/issues/3149) | `Clarify end-to-end filename safety in SC2038 (#3149)`; `Assert SC2038 guidance wording (#3149)` |
| [#3148](https://github.com/koalaman/shellcheck/issues/3148) | `Restrict SC2227 to find actions (#3148)` |
| [#757](https://github.com/koalaman/shellcheck/issues/757) | `Add flow-sensitive nounset diagnostics (#757)` |
| [#751](https://github.com/koalaman/shellcheck/issues/751) | `Warn about control flow in pipeline subshells (#751)` |
| [#289](https://github.com/koalaman/shellcheck/issues/289) | `Respect nonstandard IFS in SC2086 (#289)` |
| [#3351](https://github.com/koalaman/shellcheck/issues/3351) | `Handle integer expansions with nonstandard IFS (#3351)` |
| [#3447](https://github.com/koalaman/shellcheck/issues/3447) | `Avoid malformed SC2292 fixes (#3447)`; `Assert corrected SC2292 output (#3447)` |
| [#26](https://github.com/koalaman/shellcheck/issues/26) | `Clarify ineffective subshell loop control (#26)`; `Assert SC2106 loop-control wording (#26)` |
| [#3522](https://github.com/koalaman/shellcheck/issues/3522) | `Detect status clobbered by command substitutions (#3522)` |
| [#2921](https://github.com/koalaman/shellcheck/issues/2921) | `Allow remapping generic sh shebangs (#2921)`; `Test IRIX /sbin/sh remapping (#2921)` |
| [#3166](https://github.com/koalaman/shellcheck/issues/3166) | `Recognize POSIX.1-2024 case fallthrough (#3166)` |
| [#1095](https://github.com/koalaman/shellcheck/issues/1095) | `Parse variable references in trap actions (#1095)`; `Resolve trap-local assignments (#1095)` |
| [#1189](https://github.com/koalaman/shellcheck/issues/1189) | `Constrain case values from exact patterns (#1189)` |
| [#3524](https://github.com/koalaman/shellcheck/issues/3524) | SC2118 explains Ksh coprocess semantics rather than claiming the operator is unsupported. |
| [#2561](https://github.com/koalaman/shellcheck/issues/2561) | SC2350 detects literal apostrophes in double-quoted parameter default/assignment/alternate words. |
| [#2456](https://github.com/koalaman/shellcheck/issues/2456) | SC2155 detects nested command substitutions in declaration assignments, preserving readonly-local exemptions. |
| [#243](https://github.com/koalaman/shellcheck/issues/243) | Optional SC2351 (`require-variable-declarations`) implements a bounded lexical declaration policy, not runtime unset-variable proof. |
| [#2439](https://github.com/koalaman/shellcheck/issues/2439) | Optional SC2352 (`check-function-tracing-status`) identifies trailing tracing toggles whose status is tested instead of the preceding command. |

## Additional diagnostic changes

* SC2030/SC2031 distinguish independent function-local bindings while retaining
  warnings for assignments lost across subshells.
* SC2218 handles unreachable nodes consistently across supported fgl versions
  and detects bounded top-level forward calls in terminating error branches.
* SC2340 avoids proposing quotes around active bracket syntax in dynamic case
  patterns.
* Optional SC2353 (`check-filename-streams`) tracks filename delimiters through
  supported pipelines, saved files, substitutions, read loops and bounded
  function wrappers. Unknown transformations end tracking.
* Optional SC2354 (`check-exit-trap-scope`) detects bounded EXIT-action/local
  lifetime risks after function return and, on IRIX, nested explicit exits.

See [additional checks](doc/additional-checks.md) and
[diagnostic boundaries](doc/diagnostic-boundaries.md) for examples and limits.
These changes use the existing enable/disable directive syntax.

## IRIX additions and enhancements

These profiles can be used on any supported ShellCheck host. They do not
change general-purpose shell profiles merely because this fork is installed.

* `irix-sh` and `irix-ksh` model IRIX's Bourne-compatible and Korn invocation
  modes, including brace-form case syntax, nested parameter-word quoting,
  pipeline scope, inherited errexit and platform-specific utility advice.
* `irix-bsh` and `irix-jsh` model the older Bourne shell, preserving backtick,
  read/export/test and pipeline behaviour without incompatible POSIX advice.
  See [Bourne profiles](builders/irix/BOURNE-PROFILES.md).
* `irix-dtksh` models the older ksh93 language in SGI CDE 5.3.5, including its
  arrays, namerefs and unsupported newer features. See
  [dtksh profile](builders/irix/DTKSH-PROFILE.md).
* SC3068/SC3070 account for a preceding effective `_XPG=1` when checking command
  and arithmetic substitutions in `irix-sh`; the old bsh/jsh restrictions do
  not change. IRIX hexadecimal arithmetic requires `base#digits` (SC3071).
* The `irix-ksh` parser accepts the native unseparated `[[ condition ]] then`
  form. Native quoting and test/echo behaviour avoid incompatible fixes.
* IRIX profiles enable applicable platform checks and unused-suppression
  notices. SC2348 checks reordered waits under IRIX sh/ksh; SC2349 checks
  delayed EXIT actions reading locals lost at an explicit function exit.
  House-style and the additional optional analyses remain opt-in.
* `--sh-variant` explicitly remaps generic sh selection; ordinary sh is not
  implicitly treated as IRIX sh. See the [manual](shellcheck.1.md).

The [native IRIX build](builders/irix/README.md) is separate from language
profile support. It uses an opt-in legacy-GHC compatibility flag and isolated
GCC/MIPSpro build profiles; it does not change ordinary release builds or
redistribute proprietary tools. Native compilation and CPU-specific release
qualification must be established for the actual source and target built.
