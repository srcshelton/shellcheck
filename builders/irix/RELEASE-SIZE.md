# Preparing a native IRIX executable for release

## Strip a separate output

Keep the unstripped executable for debugging and recovery. IRIX's native strip
supports a separate output file:

```sh
/usr/bin/strip -o shellcheck.stripped shellcheck.unstripped
chmod 755 shellcheck.stripped
```

Run in a fresh private output directory, with a new output pathname. IRIX strip
creates mode 0644, hence the explicit chmod. Check each command's exit status.
Do not use GNU strip options from another platform or let Cabal strip dependency
archives with incompatible options.

The installed IRIX strip(1) documents up to three times the input size in
temporary space. Reserve that headroom in addition to the build's 524288 KiB
free-space floor and put scratch on an adequately sized private filesystem.
Record the tool version, command and input/output checksums; verify that the
unstripped input did not change.

Default native stripping has been exercised on a MIPSpro-built executable and
removed nonallocated debugging/comment sections without changing allocated
section payloads or program headers. The size reduction is build-dependent;
it is not a runtime-speed guarantee or qualification of another executable.

Before distributing the stripped result:

1. Compare version output and ELF entry point, ISA/ABI, program headers and
   allocated section layout/payloads with the original.
2. Run all five IRIX profiles' clean, SC2086 and SC2218 true/false gates on both
   binaries; compare exit status, stdout and stderr.
3. Perform same-source semantic comparisons and execute the actual target
   ISA/CPU variant. Keep separate results for each binary checksum.
4. Package the binary, licence and accurate source/version information. Do not
   include proprietary IRIX or MIPSpro files.

## Object splitting

The GHC 7.10.3 IRIX toolchain used by this harness reports
`--print-object-splitting-supported` as `NO`. An actual MIPSpro-backed compile
with `-split-objs` emitted `Warning: ignoring -fsplit-objs` and produced an
ordinary object file, not split objects.

Adding that flag therefore does not reduce this build. The toolchain's
`SplitObjs=NO` setting should remain unchanged unless object splitting is
implemented and independently qualified. Supporting it would require compiler
work, not a packaging option. This limitation is specific to this toolchain,
not a claim about every GHC version or target.
