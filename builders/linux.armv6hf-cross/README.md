# Experimental native-x86 ARMv6 cross builder

This builder runs GHC natively on Linux x86-64 and produces ARM1176/VFPv2
hard-float ShellCheck binaries. It is an experimental alternative to the
[emulated ARMv6 release builder](../linux.armv6hf); the existing release path
has not been switched. There is no `tag` file, so the standard release helpers
cannot select this image accidentally.

The builder uses crosstool-NG 1.28.0, GHC 9.12.2 and LLVM 19. Its ARMv6 C
toolchain/sysroot avoids distribution armhf libraries that may require ARMv7.
On Apple Silicon, Docker's `--platform linux/amd64` can exercise the recipe
through emulation, but cannot measure native-x86 build speed.

## Build and use

Use a full Git checkout and Docker with sufficient memory, disk and time for
both the C toolchain and GHC. CI requires 20 GiB free before the image build and
10 GiB before packaging; these are launch checks, not guaranteed peak usage.

From the repository root:

```sh
docker build --platform linux/amd64 --progress=plain \
  -t shellcheck-armv6-cross:qualification builders/linux.armv6hf-cross

cabal sdist
mkdir -p armv6-output
docker run --rm --platform linux/amd64 -i shellcheck-armv6-cross:qualification \
  < dist-newstyle/sdist/ShellCheck-0.11.0.tar.gz \
  > armv6-output/shellcheck.tar.gz 2> armv6-output/build.log
```

Use fresh output paths for each build and retain the source archive's checksum,
image identity, complete log and exit status. Standard output is an archive
containing `linux.armv6hf/shellcheck`; standard error is the build log. The
package driver strips the binary and checks static ELF32 ARMv6 attributes,
ARM1176 execution, a clean script and an expected SC2086 finding.

Building the compiler image is separate from building ShellCheck with an
already prepared image. Record their times separately, and distinguish cold
builds from cache reuse. No speed improvement is assumed from image creation
alone.

## Qualification in GitHub Actions

The manual [qualify-armv6-cross workflow](../../.github/workflows/qualify-armv6-cross.yml)
runs on a native AMD64 Ubuntu runner. It builds the image, packages the exact
checkout and builds that same source with both the candidate and existing
release builders.

`ci-contracts` runs the current diagnostic/profile, filename and EXIT suites
through `ci-compare`, requiring identical exit status, stdout and stderr for
both binaries under `qemu-arm-static -cpu arm1176`. Failures retain the input
and both outputs. The Dockerfile also executes actual C and Haskell/C
hard-float/64-bit ABI probes; mock ELF-validator tests do not replace these.

The workflow records separate image and package timings, image identities,
source checksums, the resolved package plan, ABI results and comparison output.
BuildKit cache reuse avoids unnecessary recompilation, but a cache is not a
permanent distributable compiler artifact. A successful current CI run is
required before publishing/selecting this as a release builder.

Target runtime and focused CLI checks have been exercised, but this is not a
claim of a clean native-AMD64 build or release-wide equivalence. Source archives
are checksum-pinned; distribution packages and Hackage resolution are captured
as provenance, not a fully reproducible dependency lock. Real ARMv6 execution
is useful additional coverage beyond the ARM1176 emulator.

## Compatibility requirements

Keep these settings when reproducing or modifying the recipe:

- **LLD:** GHC's ARM COPY-relocation probe rejects affected BFD linkers
  (binutils bug 16177). LLD is provided under both target-prefixed and GCC
  lookup names; GHC's original configure check remains enabled.
- **Hadrian index:** initialise the Cabal index before resolving Hadrian.
  Preserve the upstream Hadrian project's index-state.
- **LLVM assembler target:** GHC 9.12 invokes LLVMAS without adding a target
  triple. `armv6-llvm-as` supplies ARMv6 explicitly rather than allowing Clang
  to assemble for its AMD64 host.
- **UTF-8 locale:** hsc2hs writes upstream source comments while cross-generating
  code. Use Debian's `C.UTF-8` locale instead of an ASCII default.
- **Cross bindist installation:** `install-ghc` supplies explicit AMD64
  build/host, ARMv6 target, C compiler, ranlib and LLVM assembler settings.
  Installing with only a prefix can lose the cross configuration.

`test-llvm-assembler` and `test-hsc2hs-locale` exercise the actual tools;
`test-validate-elf.py` and `test-ci-compare.py` are host-side contract tests.
`validate-host-tools` verifies installed AMD64 tools and ARMv6 target settings.

## Primary references

- [crosstool-NG ARMv6 sample](https://github.com/crosstool-ng/crosstool-ng/blob/crosstool-ng-1.28.0/samples/armv6-unknown-linux-gnueabihf/crosstool.config)
- [GHC LLVM targets](https://github.com/ghc/ghc/blob/ghc-9.12.2-release/llvm-targets)
- [GHC ARM ISA detection](https://github.com/ghc/ghc/blob/ghc-9.12.2-release/m4/get_arm_isa.m4)
- [GHC linker COPY-relocation check](https://github.com/ghc/ghc/blob/ghc-9.12.2-release/m4/check_ld_copy_bug.m4)
