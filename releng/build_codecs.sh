#!/bin/bash

# expects BASE_DIR, PLAT_OS, ARCH, GLOBAL_CFLAGS, TESTCOMP
# exports LIBEXT, MY (prefix for installation), MS (dir for codecs source), CHECKOUT_DIR assumes this is $PWD

# need to define where other source is checked out and built (BASE_DIR)
# and where artifacts should be placed (DEST_DIR)

# define TESTCOMP to test compression (takes a long time)

# codecs' version and checksum
ZLIB_URL="https://www.zlib.net"
ZLIB_VER=1.2.13
ZLIB_CHK=b3a24de97a8fdbc835b9833169501030b8977031bcb54b3b3ac13740f846ab30

LZ4_URL="https://github.com/lz4/lz4/archive/refs/tags"
LZ4_VER=1.9.4
LZ4_CHK=0b0e3aa07c8c063ddf40b082bdf7e37a1562bda40a0ff5272957f3e987e0e54b

LZF_URL="http://dist.schmorp.de/liblzf"
LZF_SRC=liblzf-3.6
LZF_CHK=9c5de01f7b9ccae40c3f619d26a7abec9986c06c36d260c179cedd04b89fb46a

ZSTD_URL="https://github.com/facebook/zstd/releases/download"
ZSTD_VER=1.5.5
ZSTD_CHK=9c4396cc829cfae319a6e2615202e82aad41372073482fce286fac78646d3ee4

CB_URL="https://github.com/Blosc/c-blosc/archive/refs/tags"
CB_VER=1.21.2
CB_CHK=e5b4ddb4403cbbad7aab6e9ff55762ef298729c8a793c6147160c771959ea2aa

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

mkdir -p "$MS"
mkdir -p "$MY"

rm -rf "$MY/bin" "$MY/lib"

download_check_extract_pushd() {
    DL_SRC=$1
    DL_TARBALL=$2
    DL_CHECKSUM=$3
    DL_URL=$4

    if [ ! -d $DL_SRC ]; then
        

        curl -fsSLO $DL_URL/$DL_TARBALL
        echo "$DL_CHECKSUM  $DL_TARBALL" | sha256sum -c -
        if [ $? -ne 0 ]; then
          echo "$DL_TARBALL download does not match checksum"
          exit 1
        fi

        tar xzf $DL_TARBALL
    fi
    pushd $DL_SRC
}

patch_if_needed() {
    pf=$1
    tf=$(basename $pf)
    if [ ! -f "$tf.done" ]; then
        patch -p1 < $pf
        touch "$tf.done"
    fi
}

# fetch, build and install compression libraries
pushd $MS

ZLIB_SRC=zlib-$ZLIB_VER
download_check_extract_pushd $ZLIB_SRC ${ZLIB_SRC}.tar.gz $ZLIB_CHK "$ZLIB_URL"
# unpack and compile static
CFLAGS="$GLOBAL_CFLAGS" ./configure --prefix=$MY --64 --static
make clean
if [ -n "$TESTCOMP" ]; then
    make check
fi
make install
popd


download_check_extract_pushd lz4-$LZ4_VER v${LZ4_VER}.tar.gz $LZ4_CHK "$LZ4_URL"
make clean
if [ -n "$TESTCOMP" ]; then
    make CFLAGS="$GLOBAL_CFLAGS" PREFIX=$MY test
fi
make CFLAGS="$GLOBAL_CFLAGS" PREFIX=$MY install
rm -f $MY/lib/liblz4.${LIBEXT}*
popd


download_check_extract_pushd $LZF_SRC ${LZF_SRC}.tar.gz $LZF_CHK "$LZF_URL"
if [ $PLAT_OS == "win32" ]; then
    patch_if_needed $CHECKOUT_DIR/releng/liblzf-mingw64.patch
fi
CFLAGS=$GLOBAL_CFLAGS ./configure --prefix=$MY $CROSS_HOST
make clean
make install
popd


ZSTD_SRC=zstd-$ZSTD_VER
download_check_extract_pushd $ZSTD_SRC ${ZSTD_SRC}.tar.gz $ZSTD_CHK "$ZSTD_URL/v$ZSTD_VER"
if [ $PLAT_OS == "win32" ]; then
    patch_if_needed $CHECKOUT_DIR/releng/zstd-msys.patch
fi
if [ $PLAT_OS == "macos" -a $ARCH == "x86_64" ]; then
    patch_if_needed $CHECKOUT_DIR/releng/zstd-clang.patch
fi
make clean
if [ -n "$TESTCOMP" ]; then
    PATH=$MY/bin:$PATH make CFLAGS="$GLOBAL_CFLAGS -I$MY/include" LDFLAGS="-L$MY/lib" HAVE_LZMA=0 PREFIX=$MY test
fi
LDFLAGS="-L$MY/lib" make CFLAGS="$GLOBAL_CFLAGS -I$MY/include" HAVE_LZMA=0 PREFIX=$MY install
rm -f $MY/lib/libzstd.${LIBEXT}*
popd


download_check_extract_pushd c-blosc-$CB_VER v${CB_VER}.tar.gz $CB_CHK "$CB_URL"
rm -rf build
mkdir -p build && pushd build
if [ $ARCH != "x86_64" ]; then
    CMAKE_DEACTIVATE_X86_64='-DDEACTIVATE_SSE2=ON -DDEACTIVATE_AVX2=ON'
fi
$CMAKE "$CMAKE_OPTS" -DCMAKE_INSTALL_PREFIX=$MY -DPREFER_EXTERNAL_LZ4=ON -DPREFER_EXTERNAL_ZLIB=ON -DPREFER_EXTERNAL_ZSTD=ON \
-DLZ4_INCLUDE_DIR=$MY/include -DLZ4_LIBRARY=$MY/lib/liblz4.a -DZSTD_INCLUDE_DIR=$MY/include -DZSTD_LIBRARY=$MY/lib/libzstd.a \
-DCMAKE_C_FLAGS="$GLOBAL_CFLAGS -I$MY/include" -DCMAKE_EXE_LINKER_FLAGS="-L$MY/lib"  -DZLIB_ROOT=$MY -DLZ4_ROOT=$MY -DZstd_ROOT=$MY \
$CMAKE_DEACTIVATE_X86_64 -S .. -B .
make clean
if [ -n "$TESTCOMP" ]; then
    make VERBOSE=1 test
fi
make install
cp -p $MY/lib64/libblosc.a $MY/lib/
popd
popd

popd

