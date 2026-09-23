# Building ShellCheck for IRIX

IRIX language profiles work on every supported ShellCheck host; using them does
not require a native IRIX binary. See the [manual](../../shellcheck.1.md) and the
[Bourne](BOURNE-PROFILES.md) and [CDE dtksh](DTKSH-PROFILE.md) profile guides.

This directory contains an experimental **native build harness**, not a
one-command installer or a complete emulator CI pipeline. It consumes an
already qualified GHC 7.10.3 toolchain from
[haskell-ghc-irix](https://github.com/srcshelton/haskell-ghc-irix). It does not
rebuild that compiler, its bootstrap libraries or RTS, modify the global
package database, or install a system-wide ShellCheck.

## Requirements and build root

Use a full Git checkout for the harness; a Cabal source archive is sufficient
for ordinary ShellCheck builds but does not contain the native build tools.

The native harness requires:

- A licensed IRIX environment with an unprivileged build account. No particular
  account name is required.
- Bash at `/usr/local/bin/bash`, the compiler and supporting utilities at the
  paths expected by the selected profile, and enough disk for sources,
  intermediate objects and binaries. Keep at least 524288 KiB free in addition
  to the expected working space.
- A qualified GHC tree at `$IRIX_RUN_ROOT/ghc-7.10.3` and the matching toolchain
  repository helpers at `$IRIX_RUN_ROOT/repository/builders/irix`.
- Pinned dependency sources and revised Cabal descriptions resolved against
  the actual GHC/package set. Host-side plan preparation requires Python 3.11+.
- For MIPSpro, a local MIPSpro 7.4.4m installation and the private header,
  generated-C and runtime-support inputs described in [TECHNICAL.md](TECHNICAL.md).

Choose a dedicated directory on persistent storage, owned by the build account:

```sh
mkdir -p "$HOME/irix-build"
export IRIX_RUN_ROOT=$(cd "$HOME/irix-build" && pwd -P)
```

The root must already exist and be owned, writable and searchable by the
invoking account. Use an absolute physical path containing only letters,
digits, underscores, hyphens, periods and slashes. Empty values, the filesystem
root, your home directory itself, whitespace, symlink aliases, repeated or
trailing slashes, and `.`/`..` components are rejected before build-directory
writes. Paths are not silently normalized because manifests record exact
paths. All child drivers receive the same validated root.

When the variable is **unset**, the compatibility default is
`/var/tmp/haskell-ghc-irix-experiment`; it must satisfy the same checks. Set an
explicit persistent root for builds that must survive temporary-file cleanup.
Keep the build tree private; do not share mutable inputs between running builds.

## Prepare sources and select a profile

Prepare a Cabal solver plan using the native compiler metadata, download the
source archives and revised descriptions, then run on the host:

```sh
python3 builders/irix/prepare-native-plan PLAN_JSON SOURCES HACKAGE_CACHE OUTPUT
```

The tool verifies source/description hashes and orders Simple/Configure packages
for the native Cabal 1.22.5 Setup helper. Dependency portability is tested during
the native build, not inferred from dependency resolution.

| Profile | Private directory beneath the build root | Optimisation |
| --- | --- | --- |
| `functional` (default) | `shellcheck-native` | GHC `-O0` |
| `gcc` (alias `optimized`) | `shellcheck-native-optimized` | GHC/GCC `-O2`, N32, generic MIPS IV |
| `mipspro`, target unset | `shellcheck-native-mipspro` | GHC/MIPSpro `-O2`, N32, MIPS IV/R14000 |
| `mipspro`, explicit target | `shellcheck-native-mipspro-TARGET` | Target-specific policy below |

In the selected directory, stage `sources/`, `dependencies.plan`, a pristine
ShellCheck `source/` snapshot and `harness/` containing the scripts, shared
helpers and `patches/`. Apply the top-level `striptests` transformation only
to that disposable source snapshot, not to a development checkout. Preserve
the original source identity for comparison with a build on another platform.

For optimised profiles, `build-profile` must exactly match the policy in
`native-consumer-profile` or `mipspro-target-profile`. An arbitrary marker is
not qualification. Keep compiler adapters executable and stage the qualified
private Setup runner in `bin/`. Never copy completed dependency objects or
registrations from a different profile.

## Run the build

For the functional profile, run these phases in order on IRIX:

```sh
builders/irix/launch-native-shellcheck setup
builders/irix/launch-native-shellcheck dependencies
builders/irix/launch-native-shellcheck shellcheck
```

Each launch is asynchronous: wait for the actual process to exit and check
`$IRIX_RUN_ROOT/job/guest-status` before starting the next phase. A PID file
alone is not proof of liveness or completion. Per-package logs and completion
markers allow resumption without rebuilding successful packages; changed
completed plan entries are rejected.

Optimised builds require compile/link/run qualification before dependency
compilation. With the chosen `IRIX_CONSUMER_PROFILE` (and MIPSpro target, if
applicable), run `build-native-optimized --qualify-only`, the representative
dependency-C/FFI tests and the private hsc2hs gate using the exact staged
inputs. Retain the full input manifests and outputs required by
`native-compiler-selection`; the toolchain's qualification procedure supplies
these inputs. These gates are not replaced by the host mock tests.

After those processes have exited successfully:

```sh
builders/irix/select-native-compiler --select mipspro
builders/irix/select-native-compiler --check mipspro
builders/irix/build-native-selected mipspro
```

Use `gcc` for explicit GCC selection. With no processor target, `auto`
prefers qualified MIPSpro, then qualified GCC; it never falls back or changes
compiler after publishing the immutable selection. Explicit targets require
`mipspro`, not `auto`. Changing qualified inputs requires fresh qualification;
do not copy new adapters into an existing sealed build.

Dependencies install into the private prefix and package database. The final
build uses `-firix-legacy-ghc` and checks all five IRIX profiles with clean,
SC2086 and SC2218 true/false cases. A successful build produces private
`bin/shellcheck` and `native-ready`. These focused gates do not replace
same-source semantic comparisons, target execution or release qualification.
See [release preparation](RELEASE-SIZE.md) before stripping a binary.

## MIPSpro processor targets

Set `IRIX_CONSUMER_PROFILE=mipspro` and select one target:

| IRIX_MIPSPRO_TARGET | ISA | Scheduling |
| --- | --- | --- |
| `r4k` | MIPS III | R4000 |
| `r5k` | MIPS IV | R5000 |
| `r10k` | MIPS IV | R10000 |
| `r12k` | MIPS IV | R12000 |
| `r14k` | MIPS IV | R14000 |

Each target has separate objects, registrations and selection receipts. All use
N32 and conservative O2 settings; conflicting ISA/compiler options are rejected.
The target policy and root validator are part of the qualified input manifest.

Validate **all linked seed, support and dependency objects** against the target
ISA: compiling ShellCheck with MIPS III flags cannot convert a MIPS IV library.
A MIPS III IP22 worker cannot validate MIPS IV execution. A successful small C
probe is not qualification of a complete ShellCheck build or other hardware.

## Testing and CI

Set `IRIX_TEST_PARENT` to a private writable output directory before running
the host harness tests. Start with `test-native-run-root`, `test-native-setup`,
`test-native-dependencies`, `test-native-shellcheck`,
`test-native-compiler-selection` and `test-native-mipspro-adapter`.
Overlay tests additionally require the exact pinned upstream source via their
documented `IRIX_*_SOURCE` variables. Mock tests establish harness behaviour,
not native compiler or runtime correctness.

The manual [worker preflight](../../.github/workflows/qualify-irix-worker.yml)
requires an immutable, licensed worker image and checks CPU-JIT capabilities.
Graphics `rex-jit` is not CPU JIT. This preflight does not implement the later
GHC ladder, checkpoint restoration, toolchain relocation or the full native
consumer build within GitHub job limits.

Do not publish proprietary IRIX images, headers, libraries or MIPSpro with an
open-source artifact. See the toolchain repository's
[third-party notices](https://github.com/srcshelton/haskell-ghc-irix/blob/main/THIRD_PARTY_NOTICES.md).
