#!/bin/bash
set -e -x

export BASE_DIR=$HOME
export DEST_DIR="$PWD/dist"

brew install coreutils # for readlink and realpath
brew install openjdk@11

export MACOSX_DEPLOYMENT_TARGET=10.9 # minimum macOS version Mavericks for XCode 12.1+

export JAVA_HOME=/usr/local/opt/openjdk@11/libexec/openjdk.jdk/Contents/Home
export CPPFLAGS="-I$JAVA_HOME/include"

export PATH="$JAVA_HOME/bin:/usr/local/opt/coreutils/libexec/gnubin:$PATH"

# cmake3 already installed, for c-blosc
export CMAKE=cmake

export JAVA_OS=darwin

export PLAT_OS=macos

BUILD_ARCH=$(uname -m)
if [ $BUILD_ARCH == "x86_64" ]; then
# test for avx2
set +e
sysctl -n machdep.cpu.leaf7_features | grep -q AVX2
if [ $? -eq 1 ]; then
    export DONT_TEST_PLUGINS=yes
fi
set -e
fi

export ARCH=x86_64
export GLOBAL_CFLAGS="-fPIC -O3 -m64 -msse4 -mavx2" # or -mcpu=haswell, at least Intel Haswell or AMD Excavator (4th gen Bulldozer)
. releng/build_codecs.sh
X86_MY=$MY

export ARCH=aarch64
export GLOBAL_CFLAGS="-fPIC -O3 -mcpu=cortex-a53" # at least ARM Cortex-A53 (e.g. RPi 3 Model B or Zero W 2)
export CC='clang -arch arm64'
export CROSS_HOST='--build=x86_64-apple-darwin --host=aarch64-apple-darwin'

. releng/build_codecs.sh
AA64_MY=$MY
export -n CC

# Create universal2 versions of static libraries
export ARCH=universal2
UNI2_MY=$(realpath -L $X86_MY/../$ARCH)
mkdir -p $UNI2_MY/lib
for l in $AA64_MY/lib/*.a; do
    dlib=$(basename $l)
    lipo -create $l $X86_MY/lib/$dlib -output $UNI2_MY/lib/$dlib
done
ln -s $X86_MY/include $UNI2_MY/

export MY=$UNI2_MY
export CMAKE_OSX_ARCHITECTURES="x86_64;arm64"
. releng/build_hdf5.sh
UNI2_DEST=$DEST

# Create thin versions of hdf5 dynamic library
mkdir -p $UNI2_DEST/../aarch64 $UNI2_DEST/../x86_64
AA64_DEST=$(realpath -L $UNI2_DEST/../aarch64)
X86_DEST=$(realpath -L $UNI2_DEST/../x86_64)

for l in $UNI2_DEST/*.dylib; do
    dlib=$(basename $l)
    lipo -extract arm64 $l -output $AA64_DEST/$dlib
    lipo -extract x86_64 $l -output $X86_DEST/$dlib
done
for i in $UNI2_MY/include/[Hh]*.h; do
    ln -s $i $AA64_MY/include
done

export ARCH=x86_64
export GLOBAL_CFLAGS="-fPIC -O3 -m64 -msse4 -mavx2" # or -mcpu=haswell, at least Intel Haswell or AMD Excavator (4th gen Bulldozer)
export MY=$X86_MY
export DEST=$X86_DEST
. releng/build_filters.sh

if [ $BUILD_ARCH == "arm64" ]; then
    export DONT_TEST_PLUGINS=yes
else
    export -n DONT_TEST_PLUGINS
fi

export ARCH=aarch64
export GLOBAL_CFLAGS="-fPIC -O3 -mcpu=cortex-a53" # at least ARM Cortex-A53 (e.g. RPi 3 Model B or Zero W 2)
export MY=$AA64_MY
export DEST=$AA64_DEST
export CC='clang -arch arm64'
. releng/build_filters.sh

# Create universal2 versions of dynamic libraries
for l in $AA64_DEST/*.dylib; do
    dlib=$(basename $l)
    if [ ! -f $UNI2_DEST/$dlib ]; then
        lipo -create $l $X86_DEST/$dlib -output $UNI2_DEST/$dlib
    fi
done

