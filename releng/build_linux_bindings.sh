#!/bin/bash
set -e -x

export BASE_DIR=''
export DEST_DIR='/io/dist'

yum install -y git epel-release
yum install -y cmake3

export CMAKE=cmake3

# yum install -y python34 # for testing LZ4

cd /io

./releng/build_java_bindings.sh


if [ $ARCH == 'x64_64' ]; then
    export PLAT_OS=win32

    # Set up cross-compiler environment
    eval `rpm --eval %{mingw64_env}`

    export JDKDIR=/opt/jdk-11-win32

    DONT_TEST_PLUGINS=yes ./releng/build_java_bindings.sh
fi

