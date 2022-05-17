#!/bin/bash
set -e -x


./build_java_bindings.sh


if [ $ARCH == 'x64_64' ]; then
    export PLAT_OS=win32

    # Set up cross-compiler environment
    eval `rpm --eval %{mingw64_env}`

    export JDKDIR=/opt/jdk-11-win32

    DONT_TEST_PLUGINS=yes ./build_java_bindings.sh
fi

