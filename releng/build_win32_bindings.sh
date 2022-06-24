#!/bin/bash
set -e -x

BASE_DIR=$HOME
DEST_DIR="$PWD/dist"
CROSS_PREFIX='./' # used in liblzf
export BASE_DIR DEST_DIR CROSS_PREFIX


uname
which cmake
cmake --version

CMAKE=cmake
CMAKE_OPTS="-G MSYS Makefiles"
#CMAKE_OPTS="-G MinGW Makefiles"
export CMAKE CMAKE_OPTS

JAVA_HOME=`echo $JAVA_HOME_11_X64 | sed -e 's,C:,/c,' | tr \\\\ /` # make a Unix path
JAVA_OS=$PLAT_OS
ARCH=x86_64
export JAVA_HOME JAVA_OS ARCH

pacman -S --noconfirm git

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

#DONT_TEST_PLUGINS=yes
./releng/build_java_bindings.sh

