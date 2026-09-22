## Unreleased
### Added
- Opt-in `check-exit-trap-scope` (SC2354): bounded warnings for EXIT actions
  outliving ordinary function-local values after return, and proven nested
  explicit-exit calls on IRIX. Implicit errexit is deliberately not equated
  with explicit exit; the existing default SC2349 remains unchanged.
- Opt-in `check-filename-streams` (SC2353): track filename record delimiters
  through supported pipelines, saved files, substitutions, read loops and
  bounded static function calls, including loss of NUL separation after
  xargs invokes dirname/basename. Unknown transformations end tracking.
- SC2350: warn about literal single quotes in double-quoted parameter default,
  assignment and alternate-value words (#2561).
- Opt-in `require-variable-declarations` (SC2351): strict lexical declaration
  policy, independent of assignment/nounset diagnostics (#243).
- Opt-in `check-function-tracing-status` (SC2352): informational advice for
  trailing tracing toggles in directly condition-tested functions (#2439).
- SC2349: conservative IRIX sh/ksh warning when a delayed EXIT action may read
  outer or unset values after an explicitly exiting function's locals unwind.
  Accounts for static cleanup helpers and assignments; offers no autofix.
- Native-validated `irix-bsh` and `irix-jsh` aliases for IRIX's older Bourne
  shell, including its non-POSIX substitutions, read/export/test restrictions,
  pipeline scope and brace-form case syntax. Avoid incompatible POSIX advice.
- SC3070: diagnose unsupported `$((expression))` arithmetic expansion in
  `irix-sh`, while preserving IRIX ksh support and native arithmetic commands.
- SC3071: diagnose C-style hexadecimal arithmetic constants in both IRIX
  profiles; native shells require `base#digits`, such as `16#1a`.

### Fixed
- The `irix-ksh` parser accepts `if [[ condition ]] then` (and the corresponding
  `elif` form) without a false SC1010; other profiles retain the warning.
- SC3068/SC3070 recognize a preceding effective `_XPG=1` in `irix-sh`,
  respecting control flow, variable resets, function calls and subshell scope.
  The `irix-bsh`/`irix-jsh` restrictions remain unchanged.
- SC2118 explains Ksh coprocess semantics rather than claiming `|&` is
  unsupported (#3524).
- SC2155 detects command substitutions nested in parameter-expansion words,
  preserving readonly-local exemptions (#2456).
- SC2030/SC2031 distinguish independent function-local bindings with the same
  name while retaining warnings for genuine writes lost across subshells.
- SC2218 detects top-level forward calls in terminating error branches,
  preserving status-probe and redefinition exceptions.
- SC2218 no longer reports definitions after unreachable calls with older fgl
  versions; postdominators are computed only for nodes that can reach the exit.
- SC2340 no longer recommends quoting active bracket syntax in dynamic
  `case` patterns such as `*[${controls}]*`; constant prefixes and suffixes
  remain eligible for the opt-in style check.


## v0.11.0-irix.9 - 2026-09-11
### Fixed
- SC2337 preserves suppressions of disabled optional diagnostics, including
  SC2312, SC2344 and SC2345, while still identifying obsolete suppressions
  when their checks are enabled (#2367).


## v0.11.0-irix.8 - 2026-09-11
### Added
- SC3069: diagnose literal shell delimiters exposed by nested parameter-word
  quotes under `irix-sh` and `irix-ksh`.
- SC2348: `check-irix-wait-status` warning for waits whose saved status may
  have been discarded after waiting for a newer child under native IRIX sh or
  ksh.

### Changed
- Clarify IRIX SC2295 advice while retaining its valid token-local quote fix;
  avoid SC2339 style advice that would introduce invalid nested quoting.
- The `irix-sh` and `irix-ksh` profiles enable `check-irix-wait-status` and
  `check-unused-suppressions` by default. House-style checks remain opt-in.

### Fixed
- SC2311 no longer assumes Bash-style loss of `set -e` inside command
  substitutions under `irix-sh` or `irix-ksh`; both native shells inherit it.
  SC2310 still checks function calls in conditions where `set -e` is suppressed.
- SC2268 no longer removes protective `x` prefixes under `irix-ksh`; its
  native `test` also misinterprets values such as `!` and `(` as operators.


## v0.11.0-irix.7 - 2026-09-09
### Fixed
- SC2037 once again diagnoses option-like command words following an unquoted
  assignment under `irix-sh`; IRIX `/sbin/sh` does not treat them as part of
  the assigned value.
- `check-unused-suppressions` now recognizes directives used by CFG-derived
  diagnostics such as SC2317 on an unreachable here-document carrier.


## v0.11.0-irix.6 - 2026-09-09
### Fixed
- SC2094 now recognizes `cat` file operands as reads, avoiding false positives
  when a pipeline reads the same file more than once without overwriting it.


## v0.11.0-irix.5 - 2026-09-08
### Fixed
- SC2012 is suppressed for the IRIX shell profiles, where its suggested
  `find` replacement cannot safely reproduce the affected pipeline.


## v0.11.0-irix.4 - 2026-09-07
### Added
- `irix-ksh` models the Korn shell shipped with IRIX separately from `/sbin/sh`.

### Changed
- IRIX platform diagnostics now avoid advice which is unavailable or incorrect
  on IRIX while retaining compatible semantic and opt-in style checks.
- IRIX ksh models its native `echo` escape handling without suggesting `-e`.
- Numbered fork releases report their complete identifier, such as
  `0.11.0-irix.4`, across all precompiled binaries.


## v0.11.0-irix - 2026-09-04
### Added
- `--sh-variant` and the corresponding `sh-variant` configuration key can map
  generic `sh` shebangs to the locally deployed shell without affecting
  scripts with explicit dialect shebangs.
- SC2337: Optional `check-unused-suppressions` suggestion for unnecessary
  `disable` directives.
- SC2338: Optional `prefer-single-quotes` suggestion for constant strings.
- SC2339: Optional `require-quoted-parameter-expansion-words` suggestion for
  default and assignment words in parameter expansions.
- SC2340: Optional `require-single-quoted-case-patterns` suggestion for
  constant portions of case patterns.
- SC2341: Optional `prefer-env-shebangs` suggestion for non-sh interpreters.
- SC2342: Optional `require-shebang-space` suggestion for placing a space
  between `#!` and the interpreter.
- SC2343: Optional `require-variable-quotes` suggestion for consistently
  double quoting variable expansions where quoting preserves their role.
- SC2344: Optional `check-unbound-variables` warning for expansions which may
  fail when `set -u` is active.
- SC2345: Optional `check-exit-in-subshell` warning for `exit` and `return`
  inside implicit pipeline subshells.
- SC2346: Optional `require-final-case-terminator` suggestion for ending the
  final branch of a `case` statement with `;;`.
- SC2347: Warn when a command substitution overwrites `$?` before it is
  expanded later in the same Bash or Ksh command.
- SC3068: IRIX sh does not perform command substitution for `$(..)`, even
  though it accepts the text syntactically; use legacy backticks.

### Changed
- SC2106 now identifies the ineffective loop-control keyword and explains that
  the parent loop continues.
- SC2064 is now an informational request to verify intent when a trap action
  explicitly mixes immediate expansions with escaped, signal-time expansions.
- SC2086 can derive safe value constraints from bracket patterns, non-empty
  extglobs, and rejected invalid-character validators in `case` arms.

### Fixed
- Variables read from trap actions are now recognized in arithmetic and other
  shell syntax, rather than only in `$name` expansions. Assignments made before
  a read within the action are kept local to that delayed execution context.
- SC2086 now uses exact `case` patterns to constrain the selector within the
  matching arm, while respecting assignments, positional-parameter changes,
  fallthrough, and custom `IFS` values.
- SC2127 no longer reports the POSIX.1-2024 `;&` case-clause terminator for
  generic POSIX `sh`; explicit older shell dialects remain checked.
- SC2038 now recommends NUL delimiters end-to-end instead of suggesting
  `find -exec`, whose invoked command may still emit newline-delimited names.
- SC2227 is now limited to redirections lexically inside `find` command actions.
- SC2086 now accounts for nonstandard `IFS` characters when deciding that a
  known or integer-valued expansion cannot undergo word splitting.
- SC2292 no longer adds a third closing bracket when correcting a test which
  already ends with mismatched `]]`.

### Removed
- SC3003: removed since ANSI C string is specified in POSIX.1-2024


## v0.11.0 - 2025-08-03
### Added
- SC2327/SC2328: Warn about capturing the output of redirected commands.
- SC2329: Warn when (non-escaping) functions are never invoked.
- SC2330: Warn about unsupported glob matches with [[ .. ]] in BusyBox.
- SC2331: Suggest using standard -e instead of unary -a in tests.
- SC2332: Warn about `[ ! -o opt ]` being unconditionally true in Bash.
- SC3062: Warn about bashism `[ -o opt ]`.
- Optional `avoid-negated-conditions`: suggest replacing `[ ! a -eq b ]`
  with `[ a -ne b ]`, and similar for -ge/-lt/=/!=/etc (SC2335).
- Precompiled binaries for Linux riscv64 (linux.riscv64)

### Changed
- SC2002 about Useless Use Of Cat is now disabled by default. It can be
  re-enabled with `--enable=useless-use-of-cat` or equivalent directive.
- SC2236/SC2237 about replacing `[ ! -n .. ]` with `[ -z ]` and vice versa
  is now optional under `avoid-negated-conditions`.
- SC2015 about `A && B || C` no longer triggers when B is a test command.
- SC3012: Do not warn about `\<` and `\>` in test/[] as specified in POSIX.1-2024
- Diff output now uses / as path separator on Windows

### Fixed
- SC2218 about function use-before-define is now more accurate.
- SC2317 about unreachable commands is now less spammy for nested ones.
- SC2292, optional suggestion for [[ ]], now triggers for Busybox.
- Updates for Bash 5.3, including `${| cmd; }` and `source -p`

### Removed
- SC3013: removed since the operators `-ot/-nt/-ef` are specified in POSIX.1-2024


## v0.10.0 - 2024-03-07
### Added
- Precompiled binaries for macOS ARM64 (darwin.aarch64)
- Added support for busybox sh
- Added flag --rcfile to specify an rc file by name.
- Added `extended-analysis=true` directive to enable/disable dataflow analysis
  (with a corresponding --extended-analysis flag).
- SC2324: Warn when x+=1 appends instead of increments
- SC2325: Warn about multiple `!`s in dash/sh.
- SC2326: Warn about `foo | ! bar` in bash/dash/sh.
- SC3012: Warn about lexicographic-compare bashism in test like in [ ]
- SC3013: Warn bashism `test _ -op/-nt/-ef _` like in [ ]
- SC3014: Warn bashism `test _ == _` like in [ ]
- SC3015: Warn bashism `test _ =~ _` like in [ ]
- SC3016: Warn bashism `test -v _` like in [ ]
- SC3017: Warn bashism `test -a _` like in [ ]

### Fixed
- source statements with here docs now work correctly
- "(Array.!): undefined array element" error should no longer occur


## v0.9.0 - 2022-12-12
### Added
- SC2316: Warn about 'local readonly foo' and similar (thanks, patrickxia!)
- SC2317: Warn about unreachable commands
- SC2318: Warn about backreferences in 'declare x=1 y=$x'
- SC2319/SC2320: Warn when $? refers to echo/printf/[ ]/[[ ]]/test
- SC2321: Suggest removing $((..)) in array[$((idx))]=val
- SC2322: Suggest collapsing double parentheses in arithmetic contexts
- SC2323: Suggest removing wrapping parentheses in a[(x+1)]=val

### Fixed
- SC2086: Now uses DFA to make more accurate predictions about values
- SC2086: No longer warns about values declared as integer with declare -i

### Changed
- ShellCheck now has a Data Flow Analysis engine to make smarter decisions
  based on control flow rather than just syntax. Existing checks will
  gradually start using it, which may cause them to trigger differently
  (but more accurately).
- Values in directives/shellcheckrc can now be quoted with '' or ""


## v0.8.0 - 2021-11-06
### Added
- `disable=all` now conveniently disables all warnings
- `external-sources=true` directive can be added to .shellcheckrc to make
  shellcheck behave as if `-x` was specified.
- Optional `check-extra-masked-returns` for pointing out commands with
  suppressed exit codes (SC2312).
- Optional `require-double-brackets` for recommending \[\[ ]] (SC2292).
- SC2286-SC2288: Warn when command name ends in a symbol like `/.)'"`
- SC2289: Warn when command name contains tabs or linefeeds
- SC2291: Warn about repeated unquoted spaces between words in echo
- SC2292: Suggest [[ over [ in Bash/Ksh scripts (optional)
- SC2293/SC2294: Warn when calling `eval` with arrays
- SC2295: Warn about "${x#$y}" treating $y as a pattern when not quoted
- SC2296-SC2301: Improved warnings for bad parameter expansions
- SC2302/SC2303: Warn about loops over array values when using them as keys
- SC2304-SC2306: Warn about unquoted globs in expr arguments
- SC2307: Warn about insufficient number of arguments to expr
- SC2308: Suggest other approaches for non-standard expr extensions
- SC2313: Warn about `read` with unquoted, array indexed variable

### Fixed
- SC2102 about repetitions in ranges no longer triggers on [[ -v arr[xx] ]]
- SC2155 now recognizes `typeset` and local read-only `declare` statements
- SC2181 now tries to avoid triggering for error handling functions
- SC2290: Warn about misused = in declare & co, which were not caught by SC2270+
- The flag --color=auto no longer outputs color when TERM is "dumb" or unset

### Changed
- SC2048: Warning about $\* now also applies to ${array[\*]}
- SC2181 now only triggers on single condition tests like `[ $? = 0 ]`.
- Quote warnings are now emitted for declaration utilities in sh
- Leading `_` can now be used to suppress warnings about unused variables
- TTY output now includes warning level in text as well as color

### Removed
- SC1004: Literal backslash+linefeed in '' was found to be usually correct


## v0.7.2 - 2021-04-19
### Added
- `disable` directives can now be a range, e.g. `disable=SC3000-SC4000`
- SC1143: Warn about line continuations in comments
- SC2259/SC2260: Warn when redirections override pipes
- SC2261: Warn about multiple competing redirections
- SC2262/SC2263: Warn about aliases declared and used in the same parsing unit
- SC2264: Warn about wrapper functions that blatantly recurse
- SC2265/SC2266: Warn when using & or | with test statements
- SC2267: Warn when using xargs -i instead of -I
- SC2268: Warn about unnecessary x-comparisons like `[ x$var = xval ]`

### Fixed
- SC1072/SC1073 now respond to disable annotations, though ignoring parse errors
  is still purely cosmetic and does not allow ShellCheck to continue.
- Improved error reporting for trailing tokens after ]/]] and compound commands
- `#!/usr/bin/env -S shell` is now handled correctly
- Here docs with \r are now parsed correctly and give better warnings

### Changed
- Assignments are now parsed to spec, without leniency for leading $ or spaces
- POSIX/dash unsupported feature warnings now have individual SC3xxx codes
- SC1090: A leading `$x/` or `$(x)/` is now treated as `./` when locating files
- SC2154: Variables appearing in -z/-n tests are no longer considered unassigned
- SC2270-SC2285: Improved warnings about misused `=`, e.g. `${var}=42`


## v0.7.1 - 2020-04-04
### Fixed
- `-f diff` no longer claims that it found more issues when it didn't
- Known empty variables now correctly trigger SC2086
- ShellCheck should now be compatible with Cabal 3
- SC2154 and all command-specific checks now trigger for builtins
  called with `builtin`

### Added
- SC1136: Warn about unexpected characters after ]/]]
- SC2254: Suggest quoting expansions in case statements
- SC2255: Suggest using `$((..))` in `[ 2*3 -eq 6 ]`
- SC2256: Warn about translated strings that are known variables
- SC2257: Warn about arithmetic mutation in redirections
- SC2258: Warn about trailing commas in for loop elements

### Changed
- SC2230: 'command -v' suggestion is now off by default (-i deprecate-which)
- SC1081: Keywords are now correctly parsed case sensitively, with a warning


## v0.7.0 - 2019-07-28
### Added
- Precompiled binaries for macOS and Linux aarch64
- Preliminary support for fix suggestions
- New `-f diff` unified diff format for auto-fixes
- Files containing Bats tests can now be checked
- Directory wide directives can now be placed in a `.shellcheckrc`
- Optional checks: Use `--list-optional` to show a list of tests,
                   Enable with `-o` flags or `enable=name` directives
- Source paths: Use `-P dir1:dir2` or a `source-path=dir1` directive
                to specify search paths for sourced files.
- json1 format like --format=json but treats tabs as single characters
- Recognize FLAGS variables created by the shflags library.
- Site-specific changes can now be made in Custom.hs for ease of patching
- SC2154: Also warn about unassigned uppercase variables (optional)
- SC2252: Warn about `[ $a != x ] || [ $a != y ]`, similar to SC2055
- SC2251: Inform about ineffectual ! in front of commands
- SC2250: Warn about variable references without braces (optional)
- SC2249: Warn about `case` with missing default case (optional)
- SC2248: Warn about unquoted variables without special chars (optional)
- SC2247: Warn about $"(cmd)" and $"{var}"
- SC2246: Warn if a shebang's interpreter ends with /
- SC2245: Warn that Ksh ignores all but the first glob result in `[`
- SC2243/SC2244: Suggest using explicit -n for `[ $foo ]` (optional)
- SC1135: Suggest not ending double quotes just to make $ literal

### Changed
- If a directive or shebang is not specified, a `.bash/.bats/.dash/.ksh`
  extension will be used to infer the shell type when present.
- Disabling SC2120 on a function now disables SC2119 on call sites

### Fixed
- SC2183 no longer warns about missing printf args for `%()T`

## v0.6.0 - 2018-12-02
### Added
- Command line option --severity/-S for filtering by minimum severity
- Command line option --wiki-link-count/-W for showing wiki links
- SC2152/SC2151: Warn about bad `exit` values like `1234` and `"foo"`
- SC2236/SC2237: Suggest -n/-z instead of ! -z/-n
- SC2238: Warn when redirecting to a known command name, e.g. ls > rm
- SC2239: Warn if the shebang is not an absolute path, e.g. #!bin/sh
- SC2240: Warn when passing additional arguments to dot (.) in sh/dash
- SC1133: Better diagnostics when starting a line with |/||/&&

### Changed
- Most warnings now have useful end positions
- SC1117 about unknown double-quoted escape sequences has been retired

### Fixed
- SC2021 no longer triggers for equivalence classes like `[=e=]`
- SC2221/SC2222 no longer mistriggers on fall-through case branches
- SC2081 about glob matches in `[ .. ]` now also triggers for `!=`
- SC2086 no longer warns about spaces in `$#`
- SC2164 no longer suggests subshells for `cd ..; cmd; cd ..`
- `read -a` is now correctly considered an array assignment
- SC2039 no longer warns about LINENO now that it's POSIX

## v0.5.0 - 2018-05-31
### Added
- SC2233/SC2234/SC2235: Suggest removing or replacing (..) around tests
- SC2232: Warn about invalid arguments to sudo
- SC2231: Suggest quoting expansions in for loop globs
- SC2229: Warn about 'read $var'
- SC2227: Warn about redirections in the middle of 'find' commands
- SC2224/SC2225/SC2226: Warn when using mv/cp/ln without a destination
- SC2223: Quote warning specific to `: ${var=value}`
- SC1131: Warn when using `elseif` or `elsif`
- SC1128: Warn about blanks/comments before shebang
- SC1127: Warn about C-style comments

### Fixed
- Annotations intended for a command's here documents now work
- Escaped characters inside groups in =~ regexes now parse
- Associative arrays are now respected in arithmetic contexts
- SC1087 about `$var[@]` now correctly triggers on any index
- Bad expansions in here documents are no longer ignored
- FD move operations like {fd}>1- now parse correctly

### Changed
- Here docs are now terminated as per spec, rather than by presumed intent
- SC1073: 'else if' is now parsed correctly and not like 'elif'
- SC2163: 'export $name' can now be silenced with 'export ${name?}'
- SC2183: Now warns when printf arg count is not a multiple of format count

## v0.4.7 - 2017-12-08
### Added
- Statically linked binaries for Linux and Windows (see README.md)!
- `-a` flag to also include warnings in `source`d files
- SC2221/SC2222: Warn about overridden case branches
- SC2220: Warn about unhandled error cases in getopt loops
- SC2218: Warn when using functions before they're defined
- SC2216/SC2217: Warn when piping/redirecting to mv/cp and other non-readers
- SC2215: Warn about commands starting with leading dash
- SC2214: Warn about superfluous getopt flags
- SC2213: Warn about unhandled getopt flags
- SC2212: Suggest `false` over `[ ]`
- SC2211: Warn when using a glob as a command name
- SC2210: Warn when redirecting to an integer, e.g. `foo 1>2`
- SC2206/SC2207: Suggest alternatives when using word splitting in arrays
- SC1117: Warn about double quoted, undefined backslash sequences
- SC1113/SC1114/SC1115: Recognized more malformed shebangs

### Fixed
- `[ -v foo ]` no longer warns if `foo` is undefined
- SC2037 is now suppressed by quotes, e.g. `PAGER="cat" man foo`
- Ksh nested array declarations now parse correctly
- Parameter Expansion without colons are now recognized, e.g. `${foo+bar}`
- The `lastpipe` option is now respected with regard to subshell warnings
- `\(` is now respected for grouping in `[`
- Leading `\` is now ignored for commands, to allow alias suppression
- Comments are now allowed after directives to e.g. explain 'disable'


## v0.4.6 - 2017-03-26
### Added
- SC2204/SC2205: Warn about `( -z foo )` and `( foo -eq bar )`
- SC2200/SC2201: Warn about brace expansion in [/[[
- SC2198/SC2199: Warn about arrays in [/[[
- SC2196/SC2197: Warn about deprecated egrep/fgrep
- SC2195: Warn about unmatchable case branches
- SC2194: Warn about constant 'case' statements
- SC2193: Warn about `[[ file.png == *.mp3 ]]` and other unmatchables
- SC2188/SC2189: Warn about redirections without commands
- SC2186: Warn about deprecated `tempfile`
- SC1109: Warn when finding `&amp;`/`&gt;`/`&lt;` unquoted
- SC1108: Warn about missing spaces in `[ var= foo ]`

### Changed
- All files are now read as UTF-8 with lenient latin1 fallback, ignoring locale
- Unicode quotes are no longer considered syntactic quotes
- `ash` scripts will now be checked as `dash` with a warning

### Fixed
- `-c` no longer suggested when using `grep -o | wc`
- Comments and whitespace are now allowed before filewide directives
- Here doc delimiters with esoteric quoting like `foo""` are now handled
- SC2095 about `ssh` in while read loops is now suppressed when using `-n`
- `%(%Y%M%D)T` now recognized as a single formatter in `printf` checks
- `grep -F` now suppresses regex related suggestions
- Command name checks now recognize busybox applet names


## v0.4.5 - 2016-10-21
### Added
- A Docker build (thanks, kpankonen!)
- SC2185: Suggest explicitly adding path for `find`
- SC2184: Warn about unsetting globs (e.g. `unset foo[1]`)
- SC2183: Warn about `printf` with more formatters than variables
- SC2182: Warn about ignored arguments with `printf`
- SC2181: Suggest using command directly instead of `if [ $? -eq 0 ]`
- SC1106: Warn when using `test` operators in `(( 1 -eq 2 ))`

### Changed
- Unrecognized directives now causes a warning rather than parse failure.

### Fixed
- Indices in associative arrays are now parsed correctly
- Missing shebang warning squashed when specifying with a directive
- Ksh multidimensional arrays are now supported
- Variables in substring ${a:x:y} expansions now count as referenced
- SC1102 now also handles ambiguous `$((`
- Using `$(seq ..)` will no longer suggest quoting
- SC2148 (missing shebang) is now suppressed when using shell directives
- `[ a '>' b ]` is now recognized as being correctly escaped


## v0.4.4 - 2016-05-15
### Added
- Haskell Stack support (thanks,  Arguggi!)
- SC2179/SC2178: Warn when assigning/appending strings to arrays
- SC1102: Warn about ambiguous `$(((`
- SC1101: Warn when \\ linebreaks have trailing spaces

### Changed
- Directives directly after the shebang now apply to the entire file

### Fixed
- `{$i..10}` is now flagged similar to `{1..$i}`


## v0.4.3 - 2016-01-13
### Fixed
- Build now works on GHC 7.6.3 as found on Debian Stable/Ubuntu LTS


## v0.4.2 - 2016-01-09
### Added
- First class support for the `dash` shell
- The `--color` flag similar to ls/grep's (thanks, haguenau!)
- SC2174: Warn about unexpected behavior of `mkdir -pm` (thanks, eatnumber1!)
- SC2172: Warn about non-portable use of signal numbers in `trap`
- SC2171: Warn about `]]` without leading `[[`
- SC2168: Warn about `local` outside functions

### Fixed
- Warnings about unchecked `cd` will no longer trigger with `set -e`
- `[ a -nt/-ot/-ef b ]` no longer warns about being constant
- Quoted test operators like `[ foo "<" bar ]` now parse
- Escaped quotes in backticks now parse correctly


## v0.4.1 - 2015-09-05
### Fixed
- Added missing files to Cabal, fixing the build


## v0.4.0 - 2015-09-05
### Added
- Support for following `source`d files
- Support for setting default flags in `SHELLCHECK_OPTS`
- An `--external-sources` flag for following arbitrary `source`d files
- A `source` directive to override the filename to `source`
- SC2166: Suggest using `[ p ] && [ q ]` over `[ p -a q ]`
- SC2165: Warn when nested `for` loops use the same variable name
- SC2164: Warn when using `cd` without checking that it succeeds
- SC2163: Warn about `export $var`
- SC2162: Warn when using `read` without `-r`
- SC2157: Warn about `[ "$var " ]` and similar never-empty string matches

### Fixed
- `cat -vnE file` and similar will no longer flag as UUOC
- Nested trinary operators in `(( ))` now parse correctly
- Ksh `${ ..; }` command expansions now parse


## v0.3.8 - 2015-06-20
### Changed
- ShellCheck's license has changed from AGPLv3 to GPLv3.

### Added
- SC2156: Warn about injecting filenames in `find -exec sh -c "{}" \;`

### Fixed
- Variables and command substitutions in brace expansions are now parsed
- ANSI colors are now disabled on Windows
- Empty scripts now parse


## v0.3.7 - 2015-04-16
### Fixed
- Build now works on GHC 7.10
- Use `regex-tdfa` over `regex-compat` since the latter crashes on OS X.

## v0.3.6 - 2015-03-28
### Added
- SC2155: Warn about masked return values in `export foo=$(exit 1)`
- SC2154: Warn when a lowercase variable is referenced but not assigned
- SC2152/SC2151: Warn about bad `return` values like `1234` and `"foo"`
- SC2150: Warn about `find -exec "shell command" \;`

### Fixed
- `coproc` is now supported
- Trinary operator now recognized in `((..))`

### Removed
- Zsh support has been removed


## v0.3.5 - 2014-11-09
### Added
- SC2148: Warn when not including a shebang
- SC2147: Warn about literal ~ in PATH
- SC1086: Warn about `$` in for loop variables, e.g. `for $i in ..`
- SC1084: Warn when the shebang uses `!#` instead of `#!`

### Fixed
- Empty and comment-only backtick expansions now parse
- Variables used in PS1/PROMPT\_COMMAND/trap now count as referenced
- ShellCheck now skips unreadable files and directories
- `-f gcc` on empty files no longer crashes
- Variables in $".." are now considered quoted
- Warnings about expansions in single quotes now include backticks


## v0.3.4 - 2014-07-08
### Added
- SC2146: Warn about precedence when combining `find -o` with actions
- SC2145: Warn when concatenating arrays and strings

### Fixed
- Case statements now support `;&` and `;;&`
- Indices in array declarations now parse correctly
- `let` expressions now parsed as arithmetic expressions
- Escaping is now respected in here documents

### Changed
- Completely drop Makefile in favor of Cabal (thanks rodrigosetti!)


## v0.3.3 - 2014-05-29
### Added
- SC2144: Warn when using globs in `[/[[`
- SC2143: Suggesting using `grep -q` over `[ "$(.. | grep)" ]`
- SC2142: Warn when referencing positional parameters in aliases
- SC2141: Warn about suspicious IFS assignments like `IFS="\n"`
- SC2140: Warn about bad embedded quotes like `echo "var="value""`
- SC2130: Warn when using `-eq` on strings
- SC2139: Warn about define time expansions in alias definitions
- SC2129: Suggest command grouping over `a >> log; b >> log; c >> log`
- SC2128: Warn when expanding arrays without an index
- SC2126: Suggest `grep -c` over `grep|wc`
- SC2123: Warn about accidentally overriding `$PATH`, e.g. `PATH=/my/dir`
- SC1083: Warn about literal `{/}` outside of quotes
- SC1082: Warn about UTF-8 BOMs

### Fixed
- SC2051 no longer triggers for `{1,$n}`, only `{1..$n}`
- Improved detection of single quoted `sed` variables, e.g. `sed '$s///'`
- Stop warning about single quoted variables in `PS1` and similar
- Support for Zsh short form loops, `=(..)`

### Removed
- SC1000 about unescaped lonely `$`, e.g. `grep "^foo$"`


## v0.3.2 - 2014-03-22
### Added
- SC2121: Warn about trying to `set` variables, e.g. `set var = value`
- SC2120/SC2119: Warn when a function uses `$1..` if none are ever passed
- SC2117: Warn when using `su` in interactive mode, e.g. `su foo; whoami`
- SC2116: Detect useless use of echo, e.g. `for i in $(echo $var)`
- SC2115/SC2114: Detect some catastrophic `rm -r "$empty/"` mistakes
- SC1081: Warn when capitalizing keywords like `While`
- SC1077: Warn when using acute accents instead of backticks

### Fixed
- Shells are now properly recognized in shebangs containing flags
- Stop warning about math on decimals in ksh/zsh
- Stop warning about decimal comparisons with `=`, e.g. `[ $version = 1.2 ]`
- Parsing of `|&`
- `${a[x]}` not counting as a reference of `x`
- `(( x[0] ))` not counting as a reference of `x`


## v0.3.1 - 2014-02-03
### Added
- The `-s` flag to specify shell dialect
- SC2105/SC2104: Warn about `break/continue` outside loops
- SC1076: Detect invalid `[/[[` arithmetic like `[ 1 + 2 = 3 ]`
- SC1075: Suggest using `elif` over `else if`

### Fixed
- Don't warn when comma separating elements in brace expansions
- Improved detection of single quoted `sed` variables, e.g. `sed '$d'`
- Parsing of arithmetic for loops using `{..}` instead of `do..done`
- Don't treat the last pipeline stage as a subshell in ksh/zsh


## v0.3.0 - 2014-01-19
### Added
- A man page (thanks Dridi!)
- GCC compatible error reporting (`shellcheck -f gcc`)
- CheckStyle compatible XML error reporting (`shellcheck -f checkstyle`)
- Error codes for each warning, e.g. SC1234
- Allow disabling warnings with `# shellcheck disable=SC1234`
- Allow disabling warnings with `--exclude`
- SC2103: Suggest using subshells over `cd foo; bar; cd ..`
- SC2102: Warn about duplicates in char ranges, e.g. `[10-15]`
- SC2101: Warn about named classes not inside a char range, e.g. `[:digit:]`
- SC2100/SC2099: Warn about bad math expressions like `i=i+5`
- SC2098/SC2097: Warn about `foo=bar echo $foo`
- SC2095: Warn when using `ssh`/`ffmpeg` in `while read` loops
- Better warnings for missing here doc tokens

### Fixed
- Don't warn when single quoting variables with `ssh/perl/eval`
- `${!var}` is now counted as a variable reference

### Removed
- Suggestions about using parameter expansion over basename
- The `jsoncheck` binary. Use `shellcheck -f json` instead.


## v0.2.0 - 2013-10-27
### Added
- Suggest `./*` instead of `*` when passing globs to commands
- Suggest `pgrep` over `ps | grep`
- Warn about unicode quotes
- Warn about assigned but unused variables
- Inform about client side expansion when using `ssh`

### Fixed
- CLI tool now uses exit codes and stderr canonically
- Parsing of extglobs containing empty patterns
- Parsing of bash style `eval foo=(bar)`
- Parsing of expansions in here documents
- Parsing of function names containing :+-
- Don't warn about `find|xargs` when using `-print0`


## v0.1.0 - 2013-07-23
### Added
- First release
