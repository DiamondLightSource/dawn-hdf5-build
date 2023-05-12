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

JAVA_HOME=`echo $JAVA_HOME_11_X64 | sed -e 's,C:,/c,' | tr \\\\ /` # make a Unix path
JAVA_OS=$PLAT_OS
ARCH=x86_64
export JAVA_HOME JAVA_OS ARCH

pacman -S --noconfirm --needed git

case $ARCH in
  aarch64)
    export GLOBAL_CFLAGS="-fPIC -O3 -march=armv8-a" # at least ARM Cortex-A53 (e.g. RPi 3 Model B or Zero W 2)
    ;;
  x86_64|*)
    export GLOBAL_CFLAGS="-fPIC -O3 -m64 -msse4 -mavx2" # at least Intel Haswell or AMD Excavator (4th gen Bulldozer)
    ;;
esac

./releng/build_java_bindings.sh

