#!/bin/bash
set -e -x

export BASE_DIR=$HOME
export DEST_DIR="$PWD/dist"
export CROSS_PREFIX='./' # used in liblzf

#export CMAKE=cmake3


export JAVA_HOME=$JAVA_HOME_11_X64
export JAVA_OS=$PLAT_OS

export ARCH=x86_64

case $ARCH in
  aarch64)
    export GLOBAL_CFLAGS="-fPIC -O3 -march=armv8-a" # at least ARM Cortex-A53 (e.g. RPi 3 Model B or Zero W 2)
    ;;
  x86_64|*)
    export GLOBAL_CFLAGS="-fPIC -O3 -m64 -msse4 -mavx2" # at least Intel Haswell or AMD Excavator (4th gen Bulldozer)
    ;;
esac


# Set up cross-compiler environment
#eval `rpm --eval %{mingw64_env}`
#ln -sf /usr/bin/cmake3 /usr/local/bin/cmake # overwrite symlink that points /opt/_internal/pipx/venvs/cmake/bin/cmake
#export CMAKE='mingw64-cmake' # -DCMAKE_TOOLCHAIN_FILE=/io/releng/mingw64-toolchain.cmake'
#export GLOBAL_CFLAGS="$CFLAGS $GLOBAL_CFLAGS"
#export CROSS_PREFIX='mingw64-'

export MINGW_CROSS_COMPILE='yes' # trigger lz4 _int64 handling

DONT_TEST_PLUGINS=yes ./releng/build_java_bindings.sh

