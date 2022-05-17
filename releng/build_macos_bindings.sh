#!/bin/bash
set -e -x

export BASE_DIR=$HOME
export DEST_DIR="$PWD/dist"

brew install coreutils # for readlink and realpath
export PATH="/usr/local/opt/coreutils/libexec/gnubin:$PATH"

export JDKDIR=$JAVA_HOME_11_X64

export PLAT_OS=macos
export ARCH=x86_64

./releng/build_java_bindings.sh
X86_DEST=$DEST_DIR/*/$PLAT_OS/$ARCH


export ARCH=aarch64
DONT_TEST_PLUGINS=yes ./releng/build_java_bindings.sh
AA64_DEST=$(realpath -L $X86_DEST/../$ARCH)

# Create universal2 versions
UNI2_DEST=$(realpath -L $X86_DEST/../universal2)
mkdir -p $UNI_DEST
for l in $AA64_DEST/*.dylib; do
    dlib=$(basename $l)
    lipo -create $l $X86_DEST/$dlib -output $UNI2_DEST/$dlib
done


