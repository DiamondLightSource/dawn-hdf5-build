#!/bin/bash
set -e -x

export BASE_DIR=''
export DEST_DIR='/io/dist'

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


if [ $ARCH == 'x86_64' ]; then
    export PLAT_OS=win32

    # Set up cross-compiler environment
    eval `rpm --eval %{mingw64_env}`

    export JDKDIR=/opt/jdk-11-win32

    DONT_TEST_PLUGINS=yes ./releng/build_java_bindings.sh
fi

