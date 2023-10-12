#!/bin/bash
set -e -x

if [ -z "$BASE_DIR" ]; then
    export BASE_DIR=$HOME
fi
if [ -z "$DEST_DIR" ]; then
    export DEST_DIR="$PWD/dist"
fi
if [ -z "$JAVA_SRC_OUTPUT_DIR" ]; then
    export JAVA_SRC_OUTPUT_DIR="$PWD/dist-src"
fi
if [ -z "$CROSS_BUILD" ]; then
    CROSS_BUILD=n
fi

brew install coreutils # for readlink and realpath
brew install openjdk@11

export MACOSX_DEPLOYMENT_TARGET=10.9 # minimum macOS version Mavericks for XCode 12.1+

if [ -z "$HOMEBREW_PREFIX" ]; then
    HOMEBREW_PREFIX=$(realpath $(dirname $(which brew))/..)
fi

export JAVA_HOME=$HOMEBREW_PREFIX/opt/openjdk@11/libexec/openjdk.jdk/Contents/Home
export CPPFLAGS="-I$JAVA_HOME/include"

export PATH="$JAVA_HOME/bin:$HOMEBREW_PREFIX/opt/coreutils/libexec/gnubin:$PATH"

# cmake3 already installed, for c-blosc
export CMAKE=cmake

export JAVA_OS=darwin

export PLAT_OS=macos

B_ARCH=$(uname -m) # build architecture
if [ $B_ARCH == "x86_64" ]; then
    # test for avx2
    (sysctl -n machdep.cpu.leaf7_features | grep -q AVX2) || export DONT_TEST_PLUGINS=yes
    X_ARCH=arm64 # cross architecture
else
    X_ARCH=x86_64
fi

. releng/prepare_source.sh

MACOS_SO_VER=310
H5_DYLIB=libhdf5.$MACOS_SO_VER.dylib
H5_JAVA_DYLIB=libhdf5_java.$MACOS_SO_VER.dylib

set_arch_envs() {
    l_arch=$1
    export ARCH=$l_arch
    if [ $l_arch == "x86_64" ]; then
        export GLOBAL_CFLAGS="-fPIC -O3 -m64"
    elif [ $l_arch == "arm64" ]; then
        export GLOBAL_CFLAGS="-fPIC -O3 -mcpu=cortex-a53" # at least ARM Cortex-A53 (e.g. RPi 3 Model B or Zero W 2)
    else
        export GLOBAL_CFLAGS="-fPIC -O3"
    fi
}

set_arch_envs $B_ARCH
. releng/build_codecs.sh
B_MY=$MY

RPATH_OLD="@rpath/$H5_DYLIB"
RPATH_NEW="@loader_path/$H5_DYLIB"

if [ $CROSS_BUILD == "y" ]; then
    set_arch_envs $X_ARCH
    export CC="clang -arch $ARCH"
    export CMAKE_OSX_ARCHITECTURES=$ARCH
    export CROSS_HOST="--build=$B_ARCH-apple-darwin --host=$X_ARCH-apple-darwin"
    . releng/build_codecs.sh
    X_MY=$MY
    export -n CC
    unset CC

    # Create universal2 versions of static libraries
    set_arch_envs "universal2"
    U_MY=$(realpath -L $B_MY/../$ARCH)
    mkdir -p $U_MY/lib
    for l in $X_MY/lib/*.a; do
        dlib=$(basename $l)
        lipo -create $l $B_MY/lib/$dlib -output $U_MY/lib/$dlib
    done
    ln -s $B_MY/include $U_MY/

    export MY=$U_MY
    export CMAKE_OSX_ARCHITECTURES="$B_ARCH;$X_ARCH"
    . releng/build_hdf5.sh
    install_name_tool -id $H5_DYLIB $DEST/$H5_DYLIB
    install_name_tool -id $H5_JAVA_DYLIB $DEST/libhdf5_java.dylib
    install_name_tool -change "$RPATH_OLD" "$RPATH_NEW" $DEST/libhdf5_java.dylib
    U_DEST=$DEST

    # Create thin versions of hdf5 dynamic library
    mkdir -p $U_DEST/../$B_ARCH $U_DEST/../$X_ARCH
    B_DEST=$(realpath -L $U_DEST/../$B_ARCH)
    X_DEST=$(realpath -L $U_DEST/../$X_ARCH)

    for l in $U_DEST/*.dylib; do
        dlib=$(basename $l)
        lipo -extract $B_ARCH $l -output $B_DEST/$dlib
        lipo -extract $X_ARCH $l -output $X_DEST/$dlib
    done
    for i in $U_MY/include/[Hh]*.h; do
        ln -s $i $B_MY/include
    done
else
    . releng/build_hdf5.sh
    install_name_tool -id $H5_DYLIB $DEST/$H5_DYLIB
    install_name_tool -id $H5_JAVA_DYLIB $DEST/libhdf5_java.dylib
    B_DEST=$DEST
fi

set_arch_envs $B_ARCH
export MY=$B_MY
export DEST=$B_DEST
. releng/build_filters.sh

if [ $CROSS_BUILD == "y" ]; then
    export DONT_TEST_PLUGINS=yes

    set_arch_envs $X_ARCH
    export MY=$X_MY
    export DEST=$X_DEST
    export CC="clang -arch $ARCH"
    . releng/build_filters.sh

    # Create universal2 versions of dynamic libraries
    for l in $B_DEST/*.dylib; do
        dlib=$(basename $l)
        install_name_tool -change "$RPATH_OLD" "$RPATH_NEW" $l
        install_name_tool -change "$RPATH_OLD" "$RPATH_NEW" $X_DEST/$dlib
        if [ ! -f $U_DEST/$dlib ]; then
            lipo -create $l $X_DEST/$dlib -output $U_DEST/$dlib
        fi
    done
    otool -L $B_DEST/*.dylib
    otool -L $X_DEST/*.dylib
    otool -L $U_DEST/*.dylib
else
    for l in $B_DEST/*.dylib; do
        install_name_tool -change "$RPATH_OLD" "$RPATH_NEW" $l
    done
    otool -L $B_DEST/*.dylib
fi

# Copy Java source to be archived
cp -a ${HDF5_SRC}/java/src ${JAVA_SRC_OUTPUT_DIR}/
