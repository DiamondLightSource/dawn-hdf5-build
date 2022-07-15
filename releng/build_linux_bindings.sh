#!/bin/bash
set -e -x

export BASE_DIR='/io/docker-base'
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

JBIN=$(readlink -f `which java`)
export JAVA_HOME=$(dirname $(dirname $(dirname $JBIN)))
export JAVA_OS=$PLAT_OS

if [ $ARCH == "x86_64" ]; then
    # test for avx2 
    (cat /proc/cpuinfo | grep -q avx2) || export DONT_TEST_PLUGINS=yes
fi

export CC=gcc

./releng/build_java_bindings.sh

