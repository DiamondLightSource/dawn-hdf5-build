#!/bin/bash
set -e -x

if [ -z "$BASE_DIR" ]; then
    export BASE_DIR=$HOME
fi
if [ -z "$DEST_DIR" ]; then
    export DEST_DIR="$PWD/dist"
fi

export MSYS=winsymlinks:native # to unpack zstd tarball

CMAKE=cmake
CMAKE_OPTS="-G MSYS Makefiles"
export CMAKE CMAKE_OPTS

export PLAT_OS=win32

if [ -n "$JAVA_HOME_11_X64" ]; then
  JAVA_HOME=`echo $JAVA_HOME_11_X64 | sed -e 's,C:,/c,' | tr \\\\ /` # make a Unix path
elif [ -n "$JDKDIR" ]; then
  JAVA_HOME="$JDKDIR"
elif [ -z "$JAVA_HOME" ]; then
  echo "Must define JAVA_HOME or override it with JAVA_HOME_11_X64 or JDKDIR"
  exit 1
fi
JAVA_OS=$PLAT_OS
ARCH=x86_64
export JAVA_HOME JAVA_OS ARCH

export MY_MINGW_ENV_DIR=/ucrt64

pacman -S --noconfirm --needed git patch make mingw-w64-x86_64-cmake mingw-w64-ucrt-x86_64-gcc

export PATH="$MY_MINGW_ENV_DIR"/bin:"$PATH" # add universal C runtime compilers

case $ARCH in
  aarch64)
    export GLOBAL_CFLAGS="-fPIC -O3 -march=armv8-a" # at least ARM Cortex-A53 (e.g. RPi 3 Model B or Zero W 2)
    ;;
  x86_64|*)
    export GLOBAL_CFLAGS="-fPIC -O3 -m64 -msse4 -mavx2" # at least Intel Haswell or AMD Excavator (4th gen Bulldozer)
    ;;
esac

./releng/build_java_bindings.sh

