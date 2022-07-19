#!/bin/bash

# expects BASE_DIR, PLAT_OS, ARCH, GLOBAL_CFLAGS, TESTCOMP
# exports LIBEXT, MY (prefix for installation), MS (dir for codecs source), CHECKOUT_DIR assumes this is $PWD

# need to define where other source is checked out and built (BASE_DIR)
# and where artifacts should be placed (DEST_DIR)

# define TESTCOMP to test compression (takes a long time)

# codecs' version and checksum
ZLIB_VER=1.2.12
ZLIB_CHK=91844808532e5ce316b3c010929493c0244f3d37593afd6de04f71821d5136d9
LZ4_VER=1.9.3
LZ4_CHK=030644df4611007ff7dc962d981f390361e6c97a34e5cbc393ddfbe019ffe2c1
LZF_SRC=liblzf-3.6
LZF_CHK=9c5de01f7b9ccae40c3f619d26a7abec9986c06c36d260c179cedd04b89fb46a
ZSTD_VER=1.5.2
ZSTD_CHK=7c42d56fac126929a6a85dbc73ff1db2411d04f104fae9bdea51305663a83fd0
CB_VER=1.21.1
CB_CHK=f387149eab24efa01c308e4cba0f59f64ccae57292ec9c794002232f7903b55b

case $PLAT_OS in
  linux)
    LIBEXT=so
    ;;
  macos)
    LIBEXT=dylib
    ;;
  win32)
    LIBEXT=dll
    ;;
esac

CHECKOUT_DIR=$PWD

MS=$BASE_DIR/build/src
MY=$BASE_DIR/build/opt/$PLAT_OS/$ARCH
export MY

mkdir -p $MS
mkdir -p $MY

download_check_extract_pushd() {
    DL_SRC=$1
    DL_TARBALL=$2
    DL_CHECKSUM=$3
    DL_URL=$4

    if [ ! -d $DL_SRC ]; then
        echo "$DL_CHECKSUM  $DL_TARBALL" > sha256.chksum

        curl -fsSLO $DL_URL/$DL_TARBALL
        sha256sum -c sha256.chksum
        if [ $? -ne 0 ]; then
          echo "$DL_TARBALL download does not match checksum"
          exit 1
        fi

        tar xzf $DL_TARBALL
    fi
    pushd $DL_SRC
}


# fetch, build and install compression libraries
pushd $MS

ZLIB_SRC=zlib-$ZLIB_VER
download_check_extract_pushd $ZLIB_SRC ${ZLIB_SRC}.tar.gz $ZLIB_CHK "https://www.zlib.net"
# unpack and compile static
CFLAGS="$GLOBAL_CFLAGS" ./configure --prefix=$MY --64 --static
make clean
if [ -n "$TESTCOMP" ]; then
    make check
fi
make install
popd


download_check_extract_pushd lz4-$LZ4_VER v${LZ4_VER}.tar.gz $LZ4_CHK "https://github.com/lz4/lz4/archive"
make clean
if [ -n "$TESTCOMP" ]; then
    make CFLAGS="$GLOBAL_CFLAGS" PREFIX=$MY test
fi
make CFLAGS="$GLOBAL_CFLAGS" PREFIX=$MY install
rm -f $MY/lib/liblz4.${LIBEXT}*
popd


download_check_extract_pushd $LZF_SRC ${LZF_SRC}.tar.gz $LZF_CHK "http://dist.schmorp.de/liblzf"
if [ $PLAT_OS == "win32" ]; then
    patch -p1 < $CHECKOUT_DIR/releng/liblzf-mingw64.patch
fi
CFLAGS=$GLOBAL_CFLAGS ./configure --prefix=$MY $CROSS_HOST
make clean
make install
popd


ZSTD_SRC=zstd-$ZSTD_VER
download_check_extract_pushd $ZSTD_SRC ${ZSTD_SRC}.tar.gz $ZSTD_CHK "https://github.com/facebook/zstd/releases/download/v$ZSTD_VER"
if [ $PLAT_OS == "win32" ]; then
    patch -p1 < $CHECKOUT_DIR/releng/zstd-msys.patch
fi
if [ $PLAT_OS == "macos" -a $ARCH == "x86_64" ]; then
    patch -p1 < $CHECKOUT_DIR/releng/zstd-clang.patch
fi
make clean
if [ -n "$TESTCOMP" ]; then
    PATH=$MY/bin:$PATH make CFLAGS="$GLOBAL_CFLAGS -I$MY/include" LDFLAGS="-L$MY/lib" HAVE_LZMA=0 PREFIX=$MY test
fi
LDFLAGS="-L$MY/lib" make CFLAGS="$GLOBAL_CFLAGS -I$MY/include" HAVE_LZMA=0 PREFIX=$MY install
rm -f $MY/lib/libzstd.${LIBEXT}*
popd


download_check_extract_pushd c-blosc-$CB_VER v${CB_VER}.tar.gz $CB_CHK "https://github.com/Blosc/c-blosc/archive/refs/tags"
rm -rf build
mkdir -p build && pushd build
if [ $ARCH == "x86_64" ]; then
    $CMAKE "$CMAKE_OPTS" -DCMAKE_INSTALL_PREFIX=$MY -DPREFER_EXTERNAL_LZ4=ON -DPREFER_EXTERNAL_ZLIB=ON -DPREFER_EXTERNAL_ZSTD=ON \
    -DLZ4_INCLUDE_DIR=$MY/include -DLZ4_LIBRARY=$MY/lib/liblz4.a -DZSTD_INCLUDE_DIR=$MY/include -DZSTD_LIBRARY=$MY/lib/libzstd.a \
    -DCMAKE_C_FLAGS="$GLOBAL_CFLAGS -I$MY/include" -DCMAKE_EXE_LINKER_FLAGS="-L$MY/lib"  -DZLIB_ROOT=$MY -DLZ4_ROOT=$MY -DZstd_ROOT=$MY ..
else
    $CMAKE "$CMAKE_OPTS" -DCMAKE_INSTALL_PREFIX=$MY -DPREFER_EXTERNAL_LZ4=ON -DPREFER_EXTERNAL_ZLIB=ON -DPREFER_EXTERNAL_ZSTD=ON \
    -DLZ4_INCLUDE_DIR=$MY/include -DLZ4_LIBRARY=$MY/lib/liblz4.a -DZSTD_INCLUDE_DIR=$MY/include -DZSTD_LIBRARY=$MY/lib/libzstd.a \
    -DCMAKE_C_FLAGS="$GLOBAL_CFLAGS -I$MY/include" -DCMAKE_EXE_LINKER_FLAGS="-L$MY/lib"  -DZLIB_ROOT=$MY -DLZ4_ROOT=$MY -DZstd_ROOT=$MY \
    -DDEACTIVATE_SSE2=ON -DDEACTIVATE_AVX2=ON ..
fi
make clean
if [ -n "$TESTCOMP" ]; then
    make VERBOSE=1 test
fi
make install
rm -f $MY/lib/libblosc.${LIBEXT}*
popd
popd

popd

