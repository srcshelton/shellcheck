# Native IRIX ShellCheck build

The native GHC bootstrap is maintained in
[haskell-ghc-irix](https://github.com/srcshelton/haskell-ghc-irix), including
its [producer workflow](https://github.com/srcshelton/haskell-ghc-irix/blob/main/.github/workflows/build-toolchain.yml)
and [bootstrap implementation notes](https://github.com/srcshelton/haskell-ghc-irix/blob/main/builders/irix/README.md).
The duplicate bootstrap workflow and scripts formerly in this repository have
been retired; compiler-ladder fixes belong in the toolchain repository.

ShellCheck retains the opt-in `-firix-legacy-ghc` Cabal flag. Only an explicitly
selected IRIX build uses its older GHC/deepseq compatibility bounds; the normal
release builders and test matrix keep their existing requirements. IRIX shell
dialect support does not require running ShellCheck on an IRIX host.

## Toolchain consumer milestone

A native IRIX release is still experimental. Once the producer has a validated,
relocatable toolchain, a ShellCheck-specific consumer workflow should:

1. obtain the redistributable toolchain and isolated package database by
   immutable OCI digest and inject them into an independently pinned IRIX worker;
2. build ShellCheck with `-firix-legacy-ghc`, without rebuilding the compiler ladder;
3. execute native smoke tests, then publish the stripped executable and licences.

Processor-specific builds must use matching dependency objects and be validated
on suitable hardware or an emulator. The IP22 worker cannot validate MIPS IV
execution. MIPSpro 7.4.4m has built an optimised native Fuel candidate with all
36 private dependencies and focused runtime gates. Full source-matched corpus
equivalence, relocatable packaging and an emulator CI build are separate gates;
the existence of the dialect profiles alone implies none of these results.

## Private GHC 7.10.3 consumer build

The experimental native consumer harness uses a validated GHC 7.10.3 tree at
`$IRIX_RUN_ROOT/ghc-7.10.3` (default root:
`/var/tmp/haskell-ghc-irix-experiment`). It never rebuilds the compiler, changes
its global package database or installs system-wide software. Run it as the
unprivileged build user, not root.

Prepare a dated Cabal solver plan using the actual native compiler/package
metadata, download its source archives and revised Cabal descriptions, then
run `python3 builders/irix/prepare-native-plan PLAN_JSON SOURCES HACKAGE_CACHE OUTPUT`.
This host-side tool requires Python 3.11+, verifies the source archive and
description SHA-256 hashes, and orders the Simple/Configure packages for the
native Cabal 1.22.5 helper. It does not assert that the packages are portable.

Deploy the pinned source trees to `shellcheck-native/sources`, its output as
`shellcheck-native/dependencies.plan`, and these scripts plus `patches/` to
`shellcheck-native/harness`. Place an immutable, provenance-recorded ShellCheck
source snapshot in `shellcheck-native/source`; apply the existing `striptests`
release transformation only to that copy. Preserve the same runtime source
bytes for the macOS comparison.

Run `launch-native-shellcheck setup`, then `dependencies`, then `shellcheck`
through `/usr/local/bin/bash`. The first phase builds `NativeSetup.hs` with
the native bundled Cabal. Dependencies install only to `shellcheck-native/install`
and `package.conf.d`; completed-package markers allow resumption. A changed
completed plan entry is rejected rather than silently mixing build inputs.
Each phase records `job/guest-status`, and per-package logs retain previous
attempts. Keep source/object trees when resuming a failed package.

The ShellCheck phase selects `native-shellcheck-link` with GHC's `-pgml`.
This executable adapter reuses the toolchain's
`repository/builders/irix/collapse-library-search-paths` helper to compact only
the private consumer package directories into `shellcheck-native/.library-search`.
Without this, IRIX ld32 can exhaust its search-directory limit and report a
missing system library such as `-lm` despite the library existing. Compiler and
seed search-path handling remains unchanged, as do the compiled dependencies.
Deploy the adapter executable alongside the other consumer harness scripts;
the generated symlink farm is disposable and should not enter checkpoints.

The IRIX-only Aeson 1.4.7.1 overlay omits its TH derivation/quasiquote modules
and `Lift Value` instance, which require the interpreter absent from this
compiler. Runtime JSON implementation is unchanged; non-IRIX builds retain
the original API. Its revised Cabal preimage and source checksums are guarded,
and the patch was mechanically generated and clean-replay tested. Keep the
upstream source and overlay identities in the build provenance.

The integer-logarithms 1.0.3.1 overlay checks the integer-gmp version before
using the newer `NatS#`/`NatJ#` representation. GHC 7.10.3 with the bootstrap's
integer-gmp 0.5 backend instead uses the upstream portable conversion through
`Integer`. Its native completion gate compares Integer/Natural logarithms
against an independent division-based reference across 195 positive inputs,
nine bases, word boundaries and invalid domains. Modern GMP, integer-simple,
old-base and ghc-bignum preprocessing paths remain unchanged.

The primitive 0.6.4.0 overlay excludes IRIX from its `-ftree-vectorize`
option, which Nekoware GCC 3.4.6 rejects. Its C/Haskell implementation and
other platforms' compiler options are unchanged. The header and C source
pass native syntax checks without that option; native package compilation
remains a separate validation gate.

The text 1.2.3.1 overlay selects `inttypes.h` on IRIX: its `stdint.h`
requires the MIPSpro-specific `__c99` macro, even with GCC. Other platforms
retain the upstream header. Package completion additionally requires a native
UTF-8/Latin-1 smoke covering encoding boundaries, sliced byte offsets, lazy
chunk boundaries, large buffers and invalid sequences.
Dependency smoke programs compile from their own output directories with GHC's
source search path cleared, ensuring they test the installed private packages
instead of accidentally rebuilding modules from the upstream source directory.

This first functional build uses `-O0` and disables executable/library
stripping. Cabal's default archive stripping assumes GNU `strip` options that
IRIX `strip` does not implement. Release executable stripping and processor
optimisation are separate qualification steps, not abandoned requirements.
The shellcheck phase enables only `irix-legacy-ghc`, checks both IRIX profiles
with clean and SC2086-producing inputs, and publishes a private `bin/shellcheck`
plus `native-ready` only after the native runtime gates pass. It is not a
release or a completed native/macOS equivalence result.

Focused harness tests use `IRIX_TEST_PARENT` beneath a durable session workspace:
`test-native-setup`, `test-native-dependencies`, `test-native-shellcheck`, and
`python3 test-prepare-native-plan`. `test-native-aeson-overlay` additionally
requires `IRIX_AESON_SOURCE` pointing to the exact original pinned source.
`test-native-integer-logarithms-overlay` uses `IRIX_INTEGER_LOGARITHMS_SOURCE`
for its exact upstream preimage and CPP branch matrix.
`test-native-primitive-overlay` uses `IRIX_PRIMITIVE_SOURCE` to check its
exact preimage, IRIX-only option change, unchanged C sources and safe replay.
`test-native-text-overlay` uses `IRIX_TEXT_SOURCE` to check both header
branches, unchanged non-IRIX preprocessing and safe replay.
Mock tests cover failure and resume behavior; native build/runtime results
must still be obtained on IRIX itself.

### Immutable final-C selection

After the actual five-suite and representative dependency-C/FFI gates complete,
`select-native-compiler --select auto` prefers qualified installed MIPSpro, then
qualified GCC. Explicit `mipspro` and `gcc` reject unmet capabilities instead of
falling back. A candidate with live gate processes, an existing private package
database, or completed dependency markers cannot be adopted. Do not adopt an existing
build as a fresh compiler selection.

The choice is published once in `shellcheck-native-selection/selected` under the
experiment root. Its receipt preserves the profile, compiler path/checksum and
version, exact qualified adapter/options sources, private headers/support inputs,
representative C sources, five executables, FFI executable and full gate logs.
Changed qualified inputs or an explicit request to switch compiler are errors;
`auto` does not fall back after publication. A failed publication retains its
attempt for inspection. No proprietary compiler payload is copied.

Use `select-native-compiler --check auto` to validate the immutable choice, then
`build-native-selected auto` only after fresh pinned package sources, plan,
corrected ShellCheck source and the private Setup runner have been staged and
disk space reviewed. It does not rerun successful qualification. Optimised
dependency/ShellCheck entry points require the selection, with another check
before each dependency. Original functional builds are unchanged. Existing
running/suspended jobs and their deployed harness are not migrated automatically.

An explicitly diagnosed first-package lowerer failure has one narrow recovery
entry point: `select-native-compiler --requalify-lowerer mipspro`. It requires
fresh successful five-suite and FFI attempts, an FFI `compiler-inputs.cksum`
identical to the five-suite manifest, unchanged compiler/version/profile and
all other original inputs, and no completed packages. An empty private package
database may remain. The original receipt is never changed: a separate,
append-only `lowerer-requalification` receipt records its parent checksum and
the new evidence. Checks remain fail-closed before publication. This operation
refuses stale executable cohorts, any second revision or any compiler switch;
later-package or broader input repairs need a separately reviewed workflow.

The subsequently qualified alignment/diagnostic-transport repair has its own
`--requalify-layout-transport` operation. It pins the parent receipts, admits
only the reviewed adapter/lowerer pair and fresh gate evidence, preserves the
completed package inventory, and appends a receipt rather than replacing one.
`check-native-hsc2hs` separately validates the C99-compatible private hsc2hs
template and its runtime evidence. Neither operation is a general reseal or a
permission to change active inputs. Do not replay one-time revision helpers.

`test-native-compiler-selection` exercises preference, failed/missing/stale gates,
live-process and package-state refusal, changed inputs and no mid-build fallback.
These are mock contract tests, not native compiler/runtime qualification.

## Isolated corrected and optimised Fuel candidate

`launch-native-shellcheck optimized` uses `shellcheck-native-optimized` and
its own `job`, sources, objects, package database, prefix, completion markers,
link-search farms and binary. It requires a `build-profile` containing exactly
`fuel-mips4-generic-n32-gcc346-ghc7103-O2-v2`. Prepare fresh pinned dependency sources,
the recorded corrected/stripped ShellCheck snapshot and the harness there;
copy the qualified NativeSetup runner to its private `bin`. Do not copy old
package registrations or dependency build objects. The launcher rejects a live prior
consumer build and runs this candidate at lower CPU priority.

The candidate uses GHC `-O2` and a private GCC 3.4.6 compiler/assembler adapter
with `-O2 -mabi=n32 -mips4 -mtune=mips4`, for the R14000 Fuel. GCC 3.4.6 does
not support R10000/R12000/R14000 tuning names, so this uses generic MIPS IV
scheduling, not a claimed R14000-specific scheduling model. It preserves
signed-wrap, no-strict-aliasing and non-fused floating-point semantics
(`-fwrapv -fno-strict-aliasing -mno-fused-madd`) and the existing IRIX linker
compatibility/search-path handling. The seed wrapper still ends in `-O0` and
is deliberately not edited. This is a Fuel-specific candidate, not a portable
R4k product. No GHC ladder, global package DB or seed RTS is rebuilt.

Keep native-shellcheck-cc and native-shellcheck-link executable in every
staging/overlay: GHC invokes them directly. The driver rejects missing execute
permission before compiling; the mock suite covers this failure.

Five existing runtime/clock/Unix/ByteString smoke suites must pass with the new
flags before dependencies are built. Each attempt uses fresh output directories;
compiler status, executable existence and runtime status are checked explicitly.
Native Bash 3.2.33 can ignore a failed subshell under `set -e`, so a stage label
alone is not evidence of success. The marker includes the qualified profile and
is written only after five explicit PASS records. All 36 consumer dependencies are then
rebuilt in the private prefix with the same optimisation profile, followed by
ShellCheck. Both shell-profile gates include an earlier-defined function in a
pipeline (no SC2218) and a real top-level forward call (SC2218 required).
`test-native-optimized` covers profile isolation, argument preservation,
unsafe-option rejection, qualification ordering, missing output, runtime failure,
stale-marker invalidation and explicit compiler-failure propagation.

### Experimental MIPSpro final-C candidate

`IRIX_CONSUMER_PROFILE=mipspro` has a separate `shellcheck-native-mipspro`
root and private MIPSpro 7.4.4m adapter. The working GCC GHC, seed libraries
and RTS remain unchanged. No proprietary compiler is redistributed.
The adapter fixes N32/MIPS IV/R14000, C99 and conservative `-O2` options,
records every argument transformation and rejects unreviewed options. It
never falls back to GCC inside a build. `gcc` is an explicit alias for the
existing `optimized` GCC profile. Automatic selection uses the immutable
capability-gated receipt described above, not compiler presence alone.
Final executable links explicitly append a private, checksum-verified N32
`libgcc.a` from the qualified GCC bootstrap. The unchanged GCC-built seed/RTS
needs its count-leading/trailing-zero and instruction-cache helpers; using
that runtime archive does not change the MIPSpro compiler/link-driver choice.
Keep its original path, GCC version and checksum provenance in
`compiler-config/gcc-runtime/`. Compilation, queries and pure relocatable
merges do not add it; missing or changed archive metadata rejects final links.
Final links also bracket inputs with verified GCC N32 `crtbegin.o`/`crtend.o`
and the matching `__do_global_ctors`/`__do_global_dtors` init/fini entries.
These run constructors in the unchanged GCC libraries, especially the GMP
allocation-hook registration; merely resolving ordinary symbols is not enough.
The mixed-compiler constructor fixture must prove initialization before main
and finalization at exit. These are startup objects, not a compiler fallback.

Assembly inputs use `-nocpp` to preserve GCC's `-x assembler`/lowercase
`.s` semantics. MIPSpro otherwise preprocesses assembly: a generated
`.byte` comment ending in a backslash can swallow the following directive,
silently corrupting a string. `test-native-mipspro-assembly` compiles a
two-unit byte-exact runtime regression through the actual C-to-assembly-to-object
path. It requires the private adapter and a durable test parent and retains its
assembly, objects, executable and logs for checkpointing.

MIPSpro requires a private GHC header overlay and the exact generated-C
lowerer from the toolchain repository. The lowerer preserves original `.hc`
bytes, replaces only known packed scalar types, restores ordinary packing,
and rejects other GNU constructs. It aligns complete generated StgWord data
definitions, never incomplete external references. The header patch provides
C99 inlining, standard byte-pointer arithmetic and C99 flexible array tails.
The empty N32 block-descriptor padding member is omitted without changing
its 32-byte size. Native `mipspro-rts-layout-smoke.c` must produce identical
structure sizes and field offsets using GCC seed headers and private MIPSpro
headers, including every affected flexible tail and block-descriptor field.
An empty legacy
`__stginit_*` symbol gets one inert word; GHC 7.10's `hs_add_root` ignores it.
The exact empty static module `S*_srt` emitted by GHC's non-split path is omitted
only when token analysis proves its definition is the sole occurrence. GHC's
split path already omits empty module SRTs. Any additional real reference is
rejected rather than changing its representation; comments and strings do not
count as references. All nonempty tables and referenced data stay unchanged.
Do not define GNU attributes away or modify the qualified seed headers.

Data declarations precede alignment directives in a module-unique inert helper,
which precedes the unchanged generated function bodies. This avoids MIPSpro's
pathological alignment handling when function references appear first. The adapter drains complete
compiler diagnostics into a per-invocation gzip stream, passes the actual exit
status, and sends a bounded summary to GHC. This avoids GHC 7.10's diagnostic
reader retaining enormous warning streams; failures remain losslessly available
for off-host decoding. Neither repair lowers the selected optimisation level.

The native `mipspro-packed-smoke.hc` plus `mipspro-external-smoke.hc` regression
checks same-unit, static and cross-unit data alignment, as well as packed
load/store guards and signed-wrap boundaries. `-Wimplicit` maps to the verified
native implicit-function/implicit-int diagnostic numbers 1196 and 3322; it
does not enable every optional compiler remark as `-fullwarn` would.

`build-native-optimized --qualify-only` can run the five actual compiler,
linker and runtime suites without starting dependencies. Its MIPSpro path
currently requires this mode: final compiler selection/provenance must be
sealed before a dependency build is enabled. Focused C probes and mock tests
are not substitutes for these real gates, representative dependency/FFI
qualification, both-profile ShellCheck smoke tests, or corpus validation.

After the five-suite gate, `qualify-native-dependency-c PINNED_PROBE_SOURCES`
compiles actual C from primitive 0.6.4.0, text 1.2.3.1, hashable 1.3.0.0 and
aeson 1.4.7.1 and links it to `DependencyCSmoke.hs` through the selected native
adapter. The FFI checks cover N32 Word64/Float/Double arguments, UTF-16 offset
operations and buffer guards, Latin-1/JSON decoding and 32-bit wrapping hashes.
Its fresh attempt, input checksums and separate `dependency-c-status` remain
available on failure; the `qualified` marker appears only after a real run.
`test-native-dependency-c` tests gate ordering and explicit compiler, missing
output and runtime failure propagation; mock success is not native evidence.

The MIPSpro-only text overlay follows the existing IRIX integer-header patch
and replaces GNU void-pointer arithmetic with explicit byte-pointer casts.
GCC sources are unchanged. Exact before/after checksums make application
idempotent and reject cross-profile source reuse. Generate the patch from the
exact preceding overlay's output; `test-native-text-mipspro-overlay` checks
clean replay, memory offsets/guards, idempotency and altered-preimage refusal.

SC2218 previously depended on differing `fgl.dom` unreachable-node behaviour.
`CFG.findPostDominators` now explicitly restricts the reversed graph to nodes
reachable from its exit, so older fgl cannot report every function definition
as following an unreachable call. The corpus is not modified or suppressed.

Candidate readiness is not corpus equivalence. Compare the complete test
corpus with a build from the same source on another platform. Give every
binary a distinct identity and result directory. See
[release-size qualification](RELEASE-SIZE.md) for stripping and object splitting.

Do not publish proprietary IRIX system images, headers/libraries or MIPSpro with
an open-source toolchain artifact. Redistribution requirements are recorded in
the toolchain repository's
[third-party notices](https://github.com/srcshelton/haskell-ghc-irix/blob/main/THIRD_PARTY_NOTICES.md).
