#!/bin/bash

# expects BASE_DIR, PLAT_OS, ARCH, GLOBAL_CFLAGS, MY, TESTCOMP, DEST_DIR prefix for artifacts, LIBEXT
# exports H5 (prefix for installation), DEST where specific artifacts are stored

export H5=$BASE_DIR/build/hdf5/$PLAT_OS/$ARCH
mkdir -p $H5

# use checked out version; no need to unpack
pushd $HDF5_SRC


rm -rf hdf5-build
mkdir -p hdf5-build
pushd hdf5-build

if [ -z "$TESTCOMP" ]; then
    CMAKE_UTESTS=-DBUILD_TESTING=OFF
fi

if [ $PLAT_OS == "win32" ]; then
    CMAKE_WIN32_OPTS=-DHDF5_MSVC_NAMING_CONVENTION=ON
fi

$CMAKE "$CMAKE_OPTS" $CMAKE_UTESTS -DHDF5_BUILD_JAVA=ON -DHDF5_BUILD_TOOLS=ON -DHDF5_ENABLE_THREADSAFE=ON -DHDF5_ENABLE_Z_LIB_SUPPORT=ON \
 -DZLIB_USE_EXTERNAL=OFF -DZLIB_ROOT=$MY \
 -DZLIB_INCLUDE_DIR=$MY/include -DZLIB_LIBRARY=$MY/lib/libz.a \
 -DCMAKE_C_FLAGS="$GLOBAL_CFLAGS -I$MY/include -I$JAVA_HOME/include -I$JAVA_HOME/include/$JAVA_OS" -DCMAKE_EXE_LINKER_FLAGS="-L$MY/lib" -DCMAKE_INSTALL_PREFIX=$H5 \
 -DALLOW_UNSUPPORTED=ON -DHDF5_BUILD_HL_LIB=OFF -DHDF5_BUILD_HL_TOOLS=OFF $CMAKE_WIN32_OPTS -S .. -B .

if [ -n "$TESTCOMP" ]; then
    # not necessary on GH actions as runner is not root
    if false; then
        # remove expected exception as root can write into read-only files so no exception gets thrown (see junit-failure.txt)
        OLD_FILE=$HDF5_SRC/java/test/TestH5Fbasic
        mv ${OLD_FILE}.java ${OLD_FILE}.orig
        awk '/testH5Fopen_read_only/{sub(/Test([^\n]*)/, "Test", last)} NR>1 {print last} {last=$0} END {print last}' ${OLD_FILE}.orig > ${OLD_FILE}.java
    fi
    make check
fi

if [ $PLAT_OS == "win32" ]; then
    # add quotes to classpath parameter
    find java -name build.make -exec sed -i -b -r -e 's|classpath ([^ ]+)|classpath "\1"|' '{}' \;
    # add static pthread to shared library
    sed -i -b -r -e 's|(-lkernel32)|/mingw64/lib/libwinpthread.a \1|' src/CMakeFiles/hdf5-shared.dir/build.make
fi

make VERBOSE=1 install
popd

popd

JARFILE="$H5/lib/jarhdf5-*.jar"
VERSION=`basename $JARFILE | sed -e 's/jarhdf5-\(.*\)\.jar/\1/g'`

export DEST=$DEST_DIR/$VERSION/$PLAT_OS/$ARCH
mkdir -p $DEST

cp $JARFILE $DEST
shopt -s extglob # to use extended glob (needs to be outside if statement)
if [ $PLAT_OS == "win32" ]; then
    cp -H $H5/bin/hdf5.${LIBEXT} $DEST
    cp $H5/bin/hdf5_java.${LIBEXT} $DEST
    mv $H5/lib/hdf5.lib $H5/lib/libhdf5.dll.a # rename import library so filter plugins can link to DLL
elif [ $PLAT_OS == "macos" ]; then
    cp -H $H5/lib/libhdf5.+([0-9]).${LIBEXT} $DEST
    cp $H5/lib/libhdf5_java.${LIBEXT} $DEST
else
    cp -H $H5/lib/libhdf5.${LIBEXT} $DEST
    cp $H5/lib/libhdf5_java.${LIBEXT} $DEST
fi
cp $H5/lib/libhdf5.settings $DEST


