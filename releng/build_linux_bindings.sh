#!/bin/bash
set -e -x

export BASE_DIR='/io/docker-base'
export DEST_DIR='/io/dist'

export CROSS_PREFIX='./' # used in liblzf

export CMAKE=cmake3

# yum install -y python34 # for testing LZ4; python3-3.6 brought in by cmake

cd /io

case $ARCH in
  aarch64)
    export GLOBAL_CFLAGS="-fPIC -O3 -march=armv8-a" # at least ARM Cortex-A53 (e.g. RPi 3 Model B or Zero W 2)
    ;;
  x86_64|*)
    export GLOBAL_CFLAGS="-fPIC -O3 -m64 -msse4 -mavx2" # at least Intel Haswell or AMD Excavator (4th gen Bulldozer)
    ;;
esac

JBIN=$(readlink -f `which java`)
export JAVA_HOME=$(dirname $(dirname $(dirname $JBIN)))
export JAVA_OS=$PLAT_OS

if [ $ARCH == 'x86_64' ]; then
    # test for avx2 
    set +e
    cat /proc/cpuinfo | grep -q avx2
    if [ $? -eq 1 ]; then
        export DONT_TEST_PLUGINS=yes
    fi
    set -e
fi
./releng/build_java_bindings.sh


if false; then
#if [ $ARCH == 'x86_64' ]; then
    export PLAT_OS=win32
    export JAVA_OS=$PLAT_OS

    # Set up cross-compiler environment
    eval `rpm --eval %{mingw64_env}`
    ln -sf /usr/bin/cmake3 /usr/local/bin/cmake # overwrite symlink that points /opt/_internal/pipx/venvs/cmake/bin/cmake
    export CMAKE='mingw64-cmake' # -DCMAKE_TOOLCHAIN_FILE=/io/releng/mingw64-toolchain.cmake'
    export GLOBAL_CFLAGS="$CFLAGS $GLOBAL_CFLAGS"
    export CROSS_PREFIX='mingw64-'
    export JAVA_HOME=/opt/jdk-11-win32

    DONT_TEST_PLUGINS=yes ./releng/build_java_bindings.sh
fi

