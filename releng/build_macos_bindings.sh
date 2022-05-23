#!/bin/bash
set -e -x

export BASE_DIR=$HOME
export DEST_DIR="$PWD/dist"
export CROSS_PREFIX='./' # used in liblzf

brew install coreutils # for readlink and realpath
brew install autoconf
brew install automake
brew install libtool

export PATH="/usr/local/opt/coreutils/libexec/gnubin:$PATH"

# cmake3 already installed, for c-blosc
export CMAKE=cmake

export JAVA_HOME=$JAVA_HOME_11_X64
export JAVA_OS=darwin

export PLAT_OS=macos


# test for avx2
set +e
sysctl -n machdep.cpu.leaf7_features | grep -q AVX2
if [ $? -eq 1 ]; then
    export DONT_TEST_PLUGINS=yes
fi
set -e

export ARCH=x86_64
export GLOBAL_CFLAGS="-fPIC -O3 -m64 -msse4 -mavx2" # or -mcpu=haswell, at least Intel Haswell or AMD Excavator (4th gen Bulldozer)
./releng/build_java_bindings.sh
X86_DEST=$DEST_DIR/*/$PLAT_OS/$ARCH


export ARCH=aarch64
export GLOBAL_CFLAGS="-fPIC -O3 -mcpu=cortex-a53" # at least ARM Cortex-A53 (e.g. RPi 3 Model B or Zero W 2)
export CC='clang -arch arm64'
export CROSS_HOST='--build=x86_64-apple-darwin --host=aarch64-apple-darwin'
DONT_TEST_PLUGINS=yes ./releng/build_java_bindings.sh
AA64_DEST=$(realpath -L $X86_DEST/../$ARCH)

# Create universal2 versions
UNI2_DEST=$(realpath -L $X86_DEST/../universal2)
mkdir -p $UNI2_DEST
for l in $AA64_DEST/*.dylib; do
    dlib=$(basename $l)
    lipo -create $l $X86_DEST/$dlib -output $UNI2_DEST/$dlib
done


