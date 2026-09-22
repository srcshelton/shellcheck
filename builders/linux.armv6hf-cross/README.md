# Experimental native-host ARMv6 builder

NOT qualified and NOT selected by any release workflow. There is deliberately
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

Only after successful full builds, comparison, dependency/provenance locking
and measured improvement may the release tag be changed. Existing frozen IRIX
inputs and the IRIX GHC ladder are unrelated and must remain untouched.

Primary source references:

- https://github.com/crosstool-ng/crosstool-ng/blob/crosstool-ng-1.28.0/samples/armv6-unknown-linux-gnueabihf/crosstool.config
- https://github.com/ghc/ghc/blob/ghc-9.12.2-release/llvm-targets
- https://github.com/ghc/ghc/blob/ghc-9.12.2-release/m4/get_arm_isa.m4
- https://github.com/ghc/ghc/blob/ghc-9.12.2-release/configure.ac
- https://github.com/ghc/ghc/blob/ghc-9.12.2-release/m4/check_ld_copy_bug.m4
- https://github.com/ghc/ghc/blob/ghc-9.12.2-release/m4/find_ld.m4
