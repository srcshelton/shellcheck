# ShellCheck builders

The standard release-image builders in this directory:

* Run on Linux x86\_64 with Docker
* Not contain any software that would restrict easy modification or copying
* Take a `cabal sdist` style tar.gz of the ShellCheck directory on stdin
* Output a tar.gz of artifacts on stdout, in a directory named for the arch

They build the supported release targets without requiring each target's
hardware on the build host. Target emulation is explicit where required.

An image can be built and tagged using `build_builder`,
and run on a source tarball using `run_builder`. A builder's `tag` file selects
its published image; experimental builders without that file are not release
defaults.

## Other build paths

* [Native IRIX](irix/README.md) is an experimental consumer of a separately
  built GHC toolchain. It runs in a licensed IRIX environment, not a standard
  redistributable Docker release image. IRIX system software and MIPSpro must
  not be included in public images or artifacts.
* [Native-x86 ARMv6 cross builder](linux.armv6hf-cross/README.md) is prepared
  automatically on trusted default-branch builds when its pinned GHCR image is
  missing. Only ARMv6 waits for that qualification; pull requests and other
  branches use an existing image or the emulated fallback. Qualification
  compares both paths before publishing a new cross image. Manual tagged
  release rebuilds retain the emulated builder.

When testing QEMU user-mode builders, use an isolated runner without binfmt_misc
registration to verify that the image invokes emulation explicitly. Do not
disable the host-wide binfmt_misc service on a shared development machine.
