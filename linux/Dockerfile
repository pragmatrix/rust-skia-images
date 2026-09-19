# This container was based on ubuntu 18 because we need to link with libstdc++ 6.0.25 because of ABI incompatibilities.
# <https://github.com/rust-skia/rust-skia/issues/393>
# libstdc++ versions used by this image:
# - libstdc++-10-dev is pinned to keep the C++ runtime baseline (gcc 10).
# - clang-20 on jammy works with libstdc++-10-dev.
# - Keeping gcc-10's libstdc++ preserves binary compatibility for users on older distros.
# - The glibc baseline is jammy's 2.35 (moved from focal's 2.31).
FROM --platform=linux/amd64 ubuntu:22.04
LABEL org.opencontainers.image.source=https://github.com/pragmatrix/rust-skia-images

# For github actions we need a newer git version
RUN apt-get update \
 && apt-get install -y software-properties-common \
 && add-apt-repository ppa:git-core/ppa -y

RUN apt-get install -y wget

## Add llvm package repository for ubuntu 22 (jammy))
RUN wget -O - https://apt.llvm.org/llvm-snapshot.gpg.key | apt-key add -
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

RUN curl https://sh.rustup.rs -sSf | sh -s -- -y
ENV PATH="/root/.cargo/bin:${PATH}"
RUN cargo install --locked just

# Install Android NDK

ENV ANDROID_NDK_VERSION=r26d
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
	gcc-10-aarch64-linux-gnu \
	g++-10-aarch64-linux-gnu \
	libstdc++-10-dev:arm64 \
	libgcc-10-dev:arm64

# Set up alternatives after all packages are installed
RUN update-alternatives \
	--install /usr/bin/clang clang /usr/bin/clang-20 90 \
	--slave /usr/bin/clang++ clang++ /usr/bin/clang++-20 \
	--slave /usr/bin/llvm-config llvm-config /usr/bin/llvm-config-20
RUN update-alternatives --install /usr/bin/c++ c++ /usr/bin/clang++-20 100

# Set up alternatives for aarch64 cross-compiler
RUN update-alternatives \
	--install /usr/bin/aarch64-linux-gnu-gcc aarch64-linux-gnu-gcc /usr/bin/aarch64-linux-gnu-gcc-10 100 \
	--slave /usr/bin/aarch64-linux-gnu-g++ aarch64-linux-gnu-g++ /usr/bin/aarch64-linux-gnu-g++-10

# Add script to test C++ include paths
COPY test_includes.sh /usr/local/bin/test_includes.sh
RUN chmod +x /usr/local/bin/test_includes.sh

# Run the include path tests
RUN /usr/local/bin/test_includes.sh
