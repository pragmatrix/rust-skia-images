# This container was based on ubuntu 18 because we need to link with libstdc++ 6.0.25 because of ABI incompatibilities.
# <https://github.com/rust-skia/rust-skia/issues/393>
# libstdc++ versions used by this image:
# - libstdc++-10-dev is installed for x86_64, but clang-20 picks the newest gcc installation,
#   so x86_64 builds compile against jammy's libstdc++-11-dev headers.
# - The aarch64 cross toolchain uses gcc 11 as well. Skia's Graphite backend needs the C++20
#   std::atomic wait and notify functions, which libstdc++ provides starting with gcc 11.
# - libstdc++ 11 implements atomic wait in its headers, so it does not raise the runtime
#   GLIBCXX symbol version that binaries built here require.
# - The glibc baseline is jammy's 2.35 (moved from focal's 2.31).
FROM --platform=linux/amd64 ubuntu:22.04
LABEL org.opencontainers.image.source=https://github.com/pragmatrix/rust-skia-images

# For github actions we need a newer git version
RUN apt-get update \
 && apt-get install -y software-properties-common \
 && add-apt-repository ppa:git-core/ppa -y

RUN apt-get install -y wget

# GitHub action runners cannot connect to IPv6 targets from inside the default docker bridge
# (observed: wget failing on apt.llvm.org's Fastly AAAA record with "Network is unreachable").
# GitHub considers this a permanent infrastructure limitation, wontfix:
# <https://github.com/actions/runner-images/issues/668>
# apt.llvm.org advertises AAAA records, so force IPv4 for apt (wget below gets -4).
RUN echo 'Acquire::ForceIPv4 "true";' > /etc/apt/apt.conf.d/99force-ipv4

## Add llvm package repository for ubuntu 22 (jammy))
# -4: wget has no happy-eyeballs fallback, and GitHub action runners cannot connect over IPv6.
RUN wget -4 -O - https://apt.llvm.org/llvm-snapshot.gpg.key | apt-key add -
RUN add-apt-repository "deb http://apt.llvm.org/jammy/ llvm-toolchain-jammy-20 main"

# unzip: for installing the Android NDK
# libgl1 libgl1-mesa-dev mesa-common-dev: for builds that need OpenGL
# libgles2-mesa-dev for egl support.
# clang-20 with g++-10 for the libstdc++ baseline.
# make is needed for supplemental builds.
# ninja-build for building Skia
# python3 is 3.10 on jammy, which is what emsdk tooling needs.
RUN apt-get update && apt-get install -y \
	curl \
	clang-20 \
	gcc \
	g++-10 \
	git \
	libgl1 \
	libgl1-mesa-dev \
	libgles2-mesa-dev \
	libssl-dev \
	libfontconfig1-dev \
	mesa-common-dev \
	llvm-20-dev \
	pkg-config \
	python3 \
	python3-distutils \
	unzip \
	make \
	libwayland-dev \
	ninja-build \
	libstdc++-10-dev

# Skia picks the COLRv1 struct layout from the FreeType headers at compile time, and FreeType 2.13.0
# changed that layout without a soname bump. 2.13+ headers enable COLRv1 on current distros, while
# linking stays against jammy's libfreetype (2.11.1), so Skia calling a function newer than that
# fails linking the CI test binaries. rust-skia >= m156.2 turns COLRv1 off at runtime on FreeType
# 2.11/2.12; older rust-skia versions must not be built with this image.
# <https://github.com/rust-skia/rust-skia/issues/1345>
# The SHA-256 is that of the release tarball verified against Werner Lemberg's signature. The hold
# keeps an upgrade of libfreetype-dev from writing its 2.11 headers back over these.
ARG FREETYPE_HEADERS_VERSION=2.13.3
ARG FREETYPE_HEADERS_SHA256=0550350666d427c74daeb85d5ac7bb353acba5f76956395995311a9c6f063289
RUN curl --http1.1 -sSfL -o freetype.tar.xz \
	https://download.savannah.gnu.org/releases/freetype/freetype-${FREETYPE_HEADERS_VERSION}.tar.xz \
 && echo "${FREETYPE_HEADERS_SHA256}  freetype.tar.xz" | sha256sum -c - \
 && apt-mark hold libfreetype-dev libfreetype6 \
 && rm -rf /usr/include/freetype2 \
 && mkdir /usr/include/freetype2 \
 && tar -xJf freetype.tar.xz --strip-components=2 -C /usr/include/freetype2 \
	freetype-${FREETYPE_HEADERS_VERSION}/include \
 && rm freetype.tar.xz

RUN curl https://sh.rustup.rs -sSf | sh -s -- -y
ENV PATH="/root/.cargo/bin:${PATH}"
RUN cargo install --locked just

# Install Android NDK

ENV ANDROID_NDK_VERSION=r30
ENV ANDROID_HOST=linux-x86_64

# HTTP/1.1, because of spurious HTTP/2 framing errors in the Azure / GitHub cloud.

RUN curl --http1.1 -sSf -o android-ndk.zip https://dl.google.com/android/repository/android-ndk-${ANDROID_NDK_VERSION}-linux.zip \
 && unzip android-ndk.zip \
 && rm android-ndk.zip

ENV ANDROID_NDK=/android-ndk-${ANDROID_NDK_VERSION}
ENV PATH=${PATH}:/android-ndk-${ANDROID_NDK_VERSION}/toolchains/llvm/prebuilt/${ANDROID_HOST}/bin

# wasm32-unknown-emscripten

SHELL ["/bin/bash", "-c"]

ENV EMSCRIPTEN_VER=6.0.9

RUN git clone https://github.com/emscripten-core/emsdk.git \
	&& (cd emsdk && ./emsdk install ${EMSCRIPTEN_VER}) \
	&& (cd emsdk && ./emsdk activate ${EMSCRIPTEN_VER})

# Needed for cross compilation to aarch64-unknown-linux-gnu
# Enable multiarch for arm64 to install cross-compilation libraries
RUN dpkg --add-architecture arm64
# Configure apt to use ports.ubuntu.com for arm64 packages
RUN sed -i 's|^deb http://archive.ubuntu.com/ubuntu|deb [arch=amd64] http://archive.ubuntu.com/ubuntu|g' /etc/apt/sources.list \
	&& sed -i 's|^deb http://security.ubuntu.com/ubuntu|deb [arch=amd64] http://security.ubuntu.com/ubuntu|g' /etc/apt/sources.list \
	&& echo "deb [arch=arm64] http://ports.ubuntu.com/ubuntu-ports jammy main restricted universe multiverse" >> /etc/apt/sources.list \
	&& echo "deb [arch=arm64] http://ports.ubuntu.com/ubuntu-ports jammy-updates main restricted universe multiverse" >> /etc/apt/sources.list \
	&& echo "deb [arch=arm64] http://ports.ubuntu.com/ubuntu-ports jammy-backports main restricted universe multiverse" >> /etc/apt/sources.list \
	&& echo "deb [arch=arm64] http://ports.ubuntu.com/ubuntu-ports jammy-security main restricted universe multiverse" >> /etc/apt/sources.list
RUN apt-get update && apt-get install -y --no-install-recommends \
	gcc-11-aarch64-linux-gnu \
	g++-11-aarch64-linux-gnu \
	libstdc++-11-dev:arm64 \
	libgcc-11-dev:arm64

# Set up alternatives after all packages are installed
RUN update-alternatives \
	--install /usr/bin/clang clang /usr/bin/clang-20 90 \
	--slave /usr/bin/clang++ clang++ /usr/bin/clang++-20 \
	--slave /usr/bin/llvm-config llvm-config /usr/bin/llvm-config-20
RUN update-alternatives --install /usr/bin/c++ c++ /usr/bin/clang++-20 100

# Set up alternatives for aarch64 cross-compiler
RUN update-alternatives \
	--install /usr/bin/aarch64-linux-gnu-gcc aarch64-linux-gnu-gcc /usr/bin/aarch64-linux-gnu-gcc-11 100 \
	--slave /usr/bin/aarch64-linux-gnu-g++ aarch64-linux-gnu-g++ /usr/bin/aarch64-linux-gnu-g++-11

# Add script to test C++ include paths
COPY test_includes.sh /usr/local/bin/test_includes.sh
RUN chmod +x /usr/local/bin/test_includes.sh

# Run the include path tests
RUN /usr/local/bin/test_includes.sh

# Fails the image build if a later layer replaced the FreeType 2.13+ headers installed above.
RUN printf '#include <ft2build.h>\n#include FT_FREETYPE_H\n#if FREETYPE_MAJOR == 2 && FREETYPE_MINOR < 13\n#error FreeType headers older than 2.13\n#endif\n' \
	| clang -fsyntax-only -I/usr/include/freetype2 -x c -
