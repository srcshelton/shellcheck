# Native release-size qualification

The 2026-09-21 MIPSpro candidate was tested with the installed IRIX strip,
without modifying the checksum-pinned unstripped qualification input.
This is release preparation, not a new public release or a full-corpus
equivalence result.

| Artifact | Bytes | POSIX checksum |
| --- | ---: | ---: |
| Original MIPSpro executable | 116,942,068 | 3536905206 |
| Default native strip, isolated output | 87,068,748 | 695472547 |

The reduction is 29,873,320 bytes (25.55%). The stripped SHA-256 is
`cb1717bedbf169ecfc1479094b4b2407adaadd72ab919f1bb9062a1d578c7851`.
The original SHA-256 remains
`7c5f5d833970e43e95a454906a9c27da4ed17b946595c467bf4e95f62068ddde`.

The operation was `/usr/bin/strip -o NEW_OUTPUT IMMUTABLE_INPUT`, followed
by chmod 755 because IRIX strip creates mode 0644. No -s/-k options were used.
Use a fresh private output/scratch directory, check actual exit status and
output, and recheck the original checksum. Installed strip(1) documents up
to three times the original size in temporary space: reserve that headroom
in addition to the 524288 KiB disk floor before starting. Keep an unstripped
debug/recovery copy and use a new binary identity for any validation results.

Both executables returned identical version output and identical status,
stdout and stderr for all eight irix-sh/irix-ksh clean, SC2086 and SC2218
true/false gates. Offline comparison proved identical entry point, ISA/ABI
flags, all program headers and all 39 allocated section layouts/payloads.
Default stripping removed nonallocated debugging/comment sections. These
focused checks do not replace full same-source corpus comparisons.

## Object splitting

The installed GCC-bootstrapped GHC 7.10.3 reports
`--print-object-splitting-supported` as `NO`. An actual `-O2 -split-objs`
compile using the qualified MIPSpro C/assembler/link adapters emitted
`Warning: ignoring -fsplit-objs`, then linked and ran successfully.
It produced an ordinary Main.o (6064 bytes), not split objects.

Consequently adding the flag does not reduce this build. The ladder recipes'
`SplitObjs=NO` remain unchanged. Enabling/supporting object splitting would
be separate compiler/toolchain work with its own correctness and build-time
qualification, not a release-command toggle. No GHC rebuild was performed.
