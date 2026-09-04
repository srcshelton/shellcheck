# Experimental native IRIX build

This directory is deliberately separate from the release builders. The normal
ShellCheck build and test matrix retains its existing GHC and `deepseq` bounds;
only a build explicitly configured with `-firix-legacy-ghc` enables the narrow
compatibility path required by the proposed native compiler.

The manual `build-irix.yml` workflow currently implements a fail-fast bootstrap
ladder:

1. `environment` boots the pinned IRIX 6.5.22 worker and records the installed
   compilers, build tools, inventory, and possible GMP installations.
2. `toolchain` additionally compiles and executes a C probe for every intended
   binary target. An unavailable processor flag, including `-r14000`, fails the
   job rather than publishing a mislabeled duplicate.
3. `ghc-configure` additionally has the Linux controller decompress the
   checksum-verified sources, builds a private Perl 5.8.9 `miniperl` (the
   worker's Perl 5.00405 is too old), builds a static generic-C GMP 4.2.1 seed
   (GHC rejects its bundled GMP 3.1.1 on mips64), configures the documented
   unregisterised `mips64-sgi-irix6` port in GHC 6.4.2, and generates its
   target-dependent headers. This is the first native bootstrap prerequisite,
   not yet a GHC or ShellCheck binary.

GHC 6.4.2 requires GNU C, so the compiler and `miniperl` bootstrap use the
installed GCC 3.4.6 with explicit N32/MIPS III/R4400 options. MIPSpro remains
the intended final code generator for the processor-specific ShellCheck builds;
the workflow proves those selections separately before starting the bootstrap.
The private Perl bootstrap also filters `-Wl,-woff,84` and `-pipe`: Perl's
upstream IRIX hints add or probe these optional MIPSpro-only flags even when
GCC was selected. No downloaded source is patched and the system Perl is not
replaced. Its library set is restricted to IRIX `libm` and `libc`, preventing
an optional MIPS IV Nekoware `libdb` from raising the MIPS III seed's ISA.
The GMP seed likewise uses N32/MIPS III generic C and is linked into an
executed arithmetic probe before GHC configuration. Documentation discovery is
disabled for this header-only gate, avoiding remote DocBook catalog lookups.
GHC's two target-header helper programs are also forced to the seed flags and
must identify as N32/MIPS III after they execute successfully.

The next bootstrap checkpoints, once the preceding evidence passes, are:

1. use the IRIX-generated headers in a same-version host build and mechanically
   produce GHC 6.4.2's unregisterised HC-file bundle;
2. consume that bundle under IRIX with `distrib/hc-build` and smoke-test the
   resulting native GHC;
3. advance through the minimum compiler ladder needed for ShellCheck 0.11.0;
4. build a stripped ShellCheck with `-firix-legacy-ghc`;
5. rebuild the Haskell dependencies and final executable in isolated package
   databases for each target, rather than merely relinking one common object.

The intended N32 artifacts and MIPSpro selections are:

| Artifact | ISA | Schedule option | Intended systems |
| --- | --- | --- | --- |
| `irix.mips3.n32.r4k` | MIPS III | `-r4000` | IP22/R4000 |
| `irix.mips4.n32.r5k` | MIPS IV | `-r5000` | O2/IP32 |
| `irix.mips4.n32.r10k` | MIPS IV | `-r10000` | Octane/IP30 and Origin-class R10K |
| `irix.mips4.n32.r12k` | MIPS IV | `-r12000` | Octane/IP30 and Fuel/IP35 R12K |
| `irix.mips4.n32.r14k` | MIPS IV | `-r14000` | Octane/IP30 and Fuel/IP35 R14K |

The IP22 worker executes the R4K probe and records ABI/ISA metadata for every
artifact. Its emulated R4400 correctly rejects MIPS IV programs, so the R5K,
R10K, R12K, and R14K probes are not executed by this workflow. Before release,
run every artifact on matching real hardware or a suitably configured emulator.

References:

- GHC 6.4.2 build and porting guide:
  <https://downloads.haskell.org/~ghc/6.4.2/docs/building.pdf>
- GNU MP build options:
  <https://gmplib.org/manual/Build-Options>
- sgidevnet IRIX Actions runner:
  <https://github.com/sgidevnet/irix-actions-runner>
