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
execution. MIPSpro as a final C compiler remains an experiment, not a proven
replacement for GCC. No IRIX binary or completed toolchain artifact is implied
by the availability of the IRIX shell profiles.

Do not publish proprietary IRIX system images, headers/libraries or MIPSpro with
an open-source toolchain artifact. Redistribution requirements are recorded in
the toolchain repository's
[third-party notices](https://github.com/srcshelton/haskell-ghc-irix/blob/main/THIRD_PARTY_NOTICES.md).
