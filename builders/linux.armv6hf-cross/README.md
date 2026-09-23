# Experimental native-host ARMv6 builder

Locally runtime/CLI-qualified, but NOT release-qualified or selected by any
release workflow. There is deliberately
no `tag` file: the standard build/run helpers cannot select this accidentally.
The existing linux.armv6hf builder remains the release path.

This candidate builds an ARM1176/VFPv2 hard-float C toolchain and sysroot using
crosstool-NG 1.28.0, then a native x86 GHC9.12.2 cross compiler using LLVM19.
This avoids using distribution armhf libc/libgcc binaries that may require
ARMv7. The initial config is derived from crosstool-NG's ARMv6 hard-float sample,
with an unknown vendor, no debugger/locales and bounded build parallelism.
Source archives are checksum-pinned; distribution packages and Cabal's package
index still need a captured lock/provenance record before promotion.

The recipe requires Linux x86-64. On Apple Silicon, `--platform linux/amd64`
can exercise the build through emulation, but cannot measure native-x86 speed.

## Qualification procedure

Build once, recording full logs, elapsed time, peak RAM and disk use:

```sh
docker build --platform linux/amd64 --progress=plain \
  -t shellcheck-armv6-cross:qualification builders/linux.armv6hf-cross
```

Feed an exact `cabal sdist` archive to the image and capture stdout as the
output tar and stderr as its build log. Run both old and candidate builders
against the SAME archive on the SAME native x86 runner with separate fresh
output directories. Compare non-version status/stdout/stderr results on a
representative suite, including negative cases. Both artifacts must run on
`qemu-arm-static -cpu arm1176`; real ARMv6 hardware is an additional check.

The Dockerfile gates actual C and Haskell/C hard-float/64-bit ABI execution.
The build driver additionally gates static ELF32 ARMv6 attributes, a clean
script and an expected SC2086 finding after stripping. These small gates are
necessary but do not substitute for full old/new semantic comparison.

## Native AMD64 CI integration

The manual `qualify-armv6-cross.yml` workflow builds this image on Ubuntu x86-64,
then builds this checkout's exact sdist with both this builder and the existing
emulated ARMv6 release builder. `ci-contracts` runs all current diagnostic/profile,
filename and EXIT CLI suites through `ci-compare`, which requires byte-identical
status/stdout/stderr on ARM1176. A mismatch retains its input and both outputs.
This includes newer tests beyond the frozen local 644-contract qualification.

The job captures separate image-completion and old/new package-build timings,
image identities, current sdist checksum, actual Cabal package plan, ABI evidence,
binaries and comparisons. Cached image builds and cold compiler builds are not
conflated with the timed package builds. BuildKit caching avoids rebuilding
unchanged expensive layers; there is no refresh timer or claim that a cache is
permanent. Public run artifacts retain the actual qualification output.

A passing native AMD64 CI qualification and timing run is required
before choosing/publishing a reusable release builder and updating its tag.
The normal release workflow remains on the old builder meanwhile. Distribution
packages/Hackage resolution are captured, not yet a fully reproducible lock.

Primary source references:

- https://github.com/crosstool-ng/crosstool-ng/blob/crosstool-ng-1.28.0/samples/armv6-unknown-linux-gnueabihf/crosstool.config
- https://github.com/ghc/ghc/blob/ghc-9.12.2-release/llvm-targets
- https://github.com/ghc/ghc/blob/ghc-9.12.2-release/m4/get_arm_isa.m4
- https://github.com/ghc/ghc/blob/ghc-9.12.2-release/configure.ac
- https://github.com/ghc/ghc/blob/ghc-9.12.2-release/m4/check_ld_copy_bug.m4
- https://github.com/ghc/ghc/blob/ghc-9.12.2-release/m4/find_ld.m4
