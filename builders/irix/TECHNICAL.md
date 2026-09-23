# Native IRIX build technical reference

This document explains compatibility choices needed to reproduce the native
build. For setup, supported profiles and commands, see [README.md](README.md).

## Dependency overlays

Overlays are restricted to the pinned versions and exact preimages accepted by
`apply-native-dependency-overlays`. They must not be applied to arbitrary newer
package sources or shared between GCC and MIPSpro profiles.

| Package | Reason for the overlay |
| --- | --- |
| Aeson 1.4.7.1 | Omit TH derivation/quasiquote modules and `Lift Value`, which need the interpreter absent from this GHC. Runtime JSON implementation is unchanged. |
| integer-logarithms 1.0.3.1 | Use the upstream portable conversion through Integer for integer-gmp 0.5 rather than the newer NatS#/NatJ# representation. |
| primitive 0.6.4.0 | Do not pass `-ftree-vectorize` on IRIX; Nekoware GCC 3.4.6 rejects it. |
| text 1.2.3.1 | Use `inttypes.h` because the IRIX `stdint.h` expects a MIPSpro-specific macro; the MIPSpro-only follow-up uses explicit byte-pointer arithmetic. |

Package gates exercise logarithms, encoding boundaries, sliced buffers and
representative dependency C/FFI operations. Smoke programs clear GHC's source
search path and use isolated output directories, so they test installed private
packages rather than accidentally recompiling upstream modules.

Patch files are generated from exact source preimages. Apply preceding overlays,
edit the source, regenerate the diff and prove clean replay before updating
checksums. Do not hand-edit patch hunks or weaken preimage guards.

## Compiler and linker adapters

GHC invokes the private compiler, assembler and linker adapters directly; they
must remain executable. GCC 3.4.6 uses generic MIPS IV scheduling because it
does not accept R10000/R12000/R14000 tuning names. Its adapter preserves
`-fwrapv -fno-strict-aliasing -mno-fused-madd`. MIPSpro uses N32/C99, the
selected ISA/CPU and conservative O2 controls, rejecting unreviewed options.

`native-shellcheck-link` uses the toolchain's
`collapse-library-search-paths` helper to combine private package search paths.
IRIX ld32 can otherwise exhaust its directory limit and misleadingly report a
missing system library. The resulting symlink farm is generated build state,
not a relocatable toolchain artifact.

The MIPSpro final link still needs checksum-verified N32 GCC support:
`libgcc.a`, `crtbegin.o`, `crtend.o` and the matching
`__do_global_ctors`/`__do_global_dtors` init/fini entries. The unchanged
GCC-built bootstrap libraries depend on arithmetic/cache helpers and constructor
execution, including GMP's allocation hooks. This does not switch the compiler
or final link driver to GCC. Queries and pure relocatable merges do not add
the runtime archive.

Assembly inputs use `-nocpp`. Preprocessing generated assembly can swallow
directives after a comment-ending backslash and corrupt string data.
`test-native-mipspro-assembly` checks byte-exact results through the real
C-to-assembly-to-object path. The constructor fixtures check initialization
before main and finalization at exit.

## Generated C and runtime layout

MIPSpro needs private GHC headers and the generated-C lowerer supplied by the
toolchain repository. Do not alter the qualified bootstrap headers or define
GNU attributes away. The lowerer preserves original .hc inputs, handles only
recognised constructs and rejects unsupported transformations.

The header overlay handles C99 inline functions, byte-pointer arithmetic and
flexible-array tails. It omits an empty N32 block-descriptor padding member
without changing the 32-byte layout. The native layout smoke must compare
sizes and offsets using the GCC seed headers and private MIPSpro headers.

Complete generated StgWord definitions receive alignment directives;
incomplete external declarations do not. Declarations and directives precede
generated function bodies in an inert module-unique helper to avoid
pathological compiler alignment handling. Packed-data tests cover static,
same-unit and cross-unit alignment, guarded accesses and signed wraparound.

An empty legacy `__stginit_*` receives one inert word, ignored by GHC 7.10's
`hs_add_root`. An empty non-split module SRT is omitted only when token analysis
proves the definition has no real references, matching the split-path behaviour.
Nonempty tables and referenced data remain unchanged.

Compiler stderr is drained to a lossless per-invocation gzip stream. The adapter
returns the actual compiler status and forwards a bounded diagnostic summary
to GHC, avoiding excessive memory consumption in GHC 7.10's diagnostic reader.
Decode large failure captures off-host. `-Wimplicit` maps to MIPSpro diagnostics
1196 and 3322, not every optional remark enabled by `-fullwarn`.

## Qualification and immutable receipts

Selection records the compiler/version, profile, adapters, shared root validator,
target policy, private headers/runtime objects and successful gate inputs and
outputs. An installed compiler alone is not sufficient. Live gate processes,
stale/missing outputs, changed inputs or prior package state prevent selection.

The five suites cover runtime, clock, Unix, Unix/ByteString and ByteString/Integer
operations. The dependency-C/FFI suite compiles actual primitive, text, hashable
and Aeson C and checks N32 Word64/Float/Double calls, buffer offsets/guards,
decoding and wrapping hashes. Private hsc2hs input and runtime checks are
additional gates. Check actual exit statuses: Bash 3.2's errexit behaviour is
not a substitute for explicit failure propagation.

Existing receipt formats include narrowly guarded legacy
`--requalify-lowerer` and `--requalify-layout-transport` operations. These
append receipts for exact allowed changes and preserve their original parents;
they are not general-purpose ways to reseal arbitrary inputs. New processor
targets reject these operations. For a new build, use fresh qualification and
selection instead of replaying legacy repairs.

Legacy profile identifiers containing `fuel-` remain accepted for compatibility
with existing manifests. They describe fixed ISA/compiler options, not a
required hostname or user account. Renaming them would change receipt identity.
