# Experimental: no release tag points here until native-x86 qualification.
# Build with --platform linux/amd64, from this directory as the context.
FROM debian:trixie-slim AS c-toolchain-config
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential autoconf automake libtool-bin bison flex gawk gperf \
    help2man libncurses-dev texinfo patch curl ca-certificates xz-utils \
    bzip2 unzip git python3 file rsync && rm -rf /var/lib/apt/lists/*
WORKDIR /src
RUN curl -fL --retry 3 -o ctng.tar.xz https://github.com/crosstool-ng/crosstool-ng/releases/download/crosstool-ng-1.28.0/crosstool-ng-1.28.0.tar.xz \
    && echo '5750e29a2bda5cd8d67900592576b1670a1987a4dcd5e4f6beae09138a1f5699  ctng.tar.xz' | sha256sum -c - \
    && tar xf ctng.tar.xz \
    && cd crosstool-ng-1.28.0 && ./configure --prefix=/opt/ctng && make -j2 && make install
RUN useradd --create-home builder && mkdir /opt/armv6-toolchain /work && chown builder:builder /opt/armv6-toolchain /work
USER builder
WORKDIR /work
COPY --chown=builder:builder crosstool.config defconfig
RUN /opt/ctng/bin/ct-ng defconfig

FROM c-toolchain-config AS c-toolchain
RUN /opt/ctng/bin/ct-ng build || { result=$?; tail -n 120 build.log; exit "$result"; }

FROM debian:trixie-slim
ENV TARGET=armv6-unknown-linux-gnueabihf
ENV TARGETNAME=linux.armv6hf
ENV PATH=/opt/armv6-toolchain/bin:/usr/local/bin:/usr/bin:/bin
RUN test "$(dpkg --print-architecture)" = amd64 \
    && apt-get update && apt-get install -y --no-install-recommends \
    build-essential ghc cabal-install llvm-19 clang-19 alex happy \
    autoconf automake curl ca-certificates xz-utils git qemu-user-static \
    python3 file libnuma-dev && rm -rf /var/lib/apt/lists/*
COPY --from=c-toolchain /opt/armv6-toolchain /opt/armv6-toolchain
COPY abi-probe.c /qualification/abi-probe.c
COPY validate-elf /usr/local/bin/validate-elf
RUN chmod +x /usr/local/bin/validate-elf \
    && "$TARGET-gcc" -O2 -static /qualification/abi-probe.c -o /qualification/abi-probe \
    && validate-elf /qualification/abi-probe \
    && qemu-arm-static -cpu arm1176 /qualification/abi-probe
WORKDIR /ghc
RUN curl -fL --retry 3 -o ghc.tar.xz https://downloads.haskell.org/~ghc/9.12.2/ghc-9.12.2-src.tar.xz \
    && echo '0e49cd5dde43f348c5716e5de9a5d7a0f8d68d945dc41cf75dfdefe65084f933  ghc.tar.xz' | sha256sum -c - \
    && tar xf ghc.tar.xz --strip-components=1 && rm ghc.tar.xz
# Binutils BFD still has ARM COPY-relocation bug16177; recent binutils no
# longer provides gold. Let GHC discover LLD and verify its unchanged probe.
RUN apt-get update && apt-get install -y --no-install-recommends lld-19 \
    && rm -rf /var/lib/apt/lists/* \
    && ln -s /usr/bin/ld.lld-19 "/opt/armv6-toolchain/bin/$TARGET-ld.lld" \
    && ln -s /usr/bin/ld.lld-19 /usr/local/bin/ld.lld \
    && "$TARGET-gcc" -O2 -static -fuse-ld=lld /qualification/abi-probe.c -o /qualification/lld-abi-probe \
    && validate-elf /qualification/lld-abi-probe \
    && qemu-arm-static -cpu arm1176 /qualification/lld-abi-probe \
    && dpkg-query -W > /qualification/packages.tsv
# Hadrian needs Hackage metadata before it can resolve its own dependencies.
# Its upstream cabal.project retains the pinned index-state.
RUN cabal update \
    && cabal --project-file=/ghc/hadrian/cabal.project new-build \
       --with-compiler=ghc --disable-documentation --disable-profiling \
       --disable-library-profiling -j2 --dry-run exe:hadrian
RUN ./boot.source \
    && CC="$TARGET-gcc" CXX="$TARGET-g++" CC_STAGE0=gcc CXX_STAGE0=g++ \
       LLC=llc-19 OPT=opt-19 LLVMAS=clang-19 \
       ./configure --build=x86_64-linux-gnu --host=x86_64-linux-gnu --target="$TARGET" --with-system-libffi=no \
    && ./hadrian/build --flavour=quickest --bignum=native -j2 --prefix=/usr/local install
COPY AbiProbe.hs /qualification/AbiProbe.hs
RUN "$TARGET-ghc" -O2 -static -optl-static -v /qualification/AbiProbe.hs \
       /qualification/abi-probe.c -optc-DHASKELL_FFI -o /qualification/hs-abi-probe \
    && validate-elf /qualification/hs-abi-probe \
    && qemu-arm-static -cpu arm1176 /qualification/hs-abi-probe
ENV CABALOPTS="--ghc-options;-split-sections -optc-Os -optl-static;--with-compiler=armv6-unknown-linux-gnueabihf-ghc;--with-hc-pkg=armv6-unknown-linux-gnueabihf-ghc-pkg;--with-gcc=armv6-unknown-linux-gnueabihf-gcc;-c;hashable -arch-native"
RUN cabal update && IFS=';' && cabal install --dependencies-only --enable-executable-static $CABALOPTS ShellCheck-0.11.0
COPY build /usr/local/bin/build
RUN chmod +x /usr/local/bin/build
WORKDIR /scratch
ENTRYPOINT ["/usr/local/bin/build"]
