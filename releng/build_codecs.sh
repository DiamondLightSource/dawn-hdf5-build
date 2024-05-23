#!/bin/bash

# expects BASE_DIR, PLAT_OS, ARCH, GLOBAL_CFLAGS, TESTCOMP
# exports LIBEXT, MY (prefix for installation), MS (dir for codecs source), CHECKOUT_DIR assumes this is $PWD

# need to define where other source is checked out and built (BASE_DIR)
# and where artifacts should be placed (DEST_DIR)

# define TESTCOMP to test compression (takes a long time)

# codecs' version and checksum
ZLIB_URL="https://www.zlib.net"
ZLIB_VER=1.3.1
ZLIB_CHK=9a93b2b7dfdac77ceba5a558a580e74667dd6fede4585b91eefb60f03b72df23

LZ4_URL="https://github.com/lz4/lz4/releases/download"
LZ4_VER=1.9.4
LZ4_CHK=0b0e3aa07c8c063ddf40b082bdf7e37a1562bda40a0ff5272957f3e987e0e54b

LZF_URL="http://dist.schmorp.de/liblzf"
LZF_SRC=liblzf-3.6
LZF_CHK=9c5de01f7b9ccae40c3f619d26a7abec9986c06c36d260c179cedd04b89fb46a

ZSTD_URL="https://github.com/facebook/zstd/releases/download"
ZSTD_VER=1.5.6
ZSTD_CHK=8c29e06cf42aacc1eafc4077ae2ec6c6fcb96a626157e0593d5e82a34fd403c1

CB_URL="https://github.com/Blosc/c-blosc/archive/refs/tags"
CB_VER=1.21.6
CB_CHK=9fcd60301aae28f97f1301b735f966cc19e7c49b6b4321b839b4579a0c156f38

ZLIB_64=--64

case $PLAT_OS in
  linux)
    LIBEXT=so
    if [ $ARCH == "aarch64" ]; then
      ZLIB_64="" # do not use --64 for Aarch64 build as gcc does not recognise -m64
    fi
    ;;
  macos)
    LIBEXT=dylib
    ;;
  win32)
    LIBEXT=dll
    ;;
esac

CHECKOUT_DIR=$PWD

if [ "$MY" == "${MY/$ARCH/}" ]; then # arch does not match (for cross-compiling)
  export MY=$BASE_DIR/build/opt/$PLAT_OS/$ARCH
fi
if [ -z "$MS" ]; then
  export MS=$BASE_DIR/build/src
fi
mkdir -p "$MY"
mkdir -p "$MS"


rm -rf "$MY/bin" "$MY/lib"

CACHE=$CHECKOUT_DIR/cache
mkdir -p $CACHE

download_check_extract_pushd() {
  DL_SRC=$1
  DL_TARBALL=$CACHE/$2
  DL_CHECKSUM=$3
  DL_URL=$4/$2

  if [ ! -d $DL_SRC ]; then
    if [ ! -f $DL_TARBALL ]; then
      curl -fsSL -o $DL_TARBALL $DL_URL
      echo "$DL_CHECKSUM  $DL_TARBALL" | sha256sum -c -
      if [ $? -ne 0 ]; then
        echo "$DL_TARBALL download does not match checksum"
        exit 1
      fi
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
CFLAGS="$GLOBAL_CFLAGS" ./configure --prefix=$MY $ZLIB_64 --static
make clean
if [ -n "$TESTCOMP" ]; then
    make check
fi
make install
popd

if [ $ARCH == "x86_64" ]; then
    LOCAL_CFLAGS="$GLOBAL_CFLAGS -m64 -msse4 -mavx2" # at least Intel Haswell or AMD Excavator (4th gen Bulldozer)
else
    LOCAL_CFLAGS="$GLOBAL_CFLAGS -march=armv8-a" # at least ARM Cortex-A53 (e.g. RPi 3 Model B or Zero W 2)
fi

LZ4_SRC=lz4-$LZ4_VER
download_check_extract_pushd $LZ4_SRC ${LZ4_SRC}.tar.gz $LZ4_CHK "$LZ4_URL/v$LZ4_VER"
make clean
if [ -n "$TESTCOMP" ]; then
    make CFLAGS="$LOCAL_CFLAGS" PREFIX=$MY test
fi
make CFLAGS="$LOCAL_CFLAGS" PREFIX=$MY install
rm -f $MY/lib/liblz4.${LIBEXT}*
popd

if [ ! "$SKIP_LZF" == "yes" ]; then
download_check_extract_pushd $LZF_SRC ${LZF_SRC}.tar.gz $LZF_CHK "$LZF_URL"
if [ $PLAT_OS == "win32" ]; then
    patch_if_needed $CHECKOUT_DIR/releng/liblzf-mingw64.patch
fi
CFLAGS=$LOCAL_CFLAGS ./configure --prefix=$MY $CROSS_HOST
make clean
make install
popd
fi

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
    PATH=$MY/bin:$PATH make CFLAGS="$LOCAL_CFLAGS -I$MY/include" LDFLAGS="-L$MY/lib" HAVE_LZMA=0 PREFIX=$MY test
fi
LDFLAGS="-L$MY/lib" make CFLAGS="$LOCAL_CFLAGS -I$MY/include" HAVE_LZMA=0 PREFIX=$MY install
rm -f $MY/lib/libzstd.${LIBEXT}*
popd


download_check_extract_pushd c-blosc-$CB_VER v${CB_VER}.tar.gz $CB_CHK "$CB_URL"
patch_if_needed $CHECKOUT_DIR/releng/c-blosc.patch
rm -rf build
mkdir -p build && pushd build
if [ $ARCH != "x86_64" ]; then
    CMAKE_DEACTIVATE_X86_64='-DDEACTIVATE_SSE2=ON -DDEACTIVATE_AVX2=ON'
fi
if [ -z "$TESTCOMP" ]; then
    CMAKE_NO_TESTS='-DBUILD_SHARED=OFF -DBUILD_TESTS=OFF -DBUILD_FUZZERS=OFF -DBUILD_BENCHMARKS=OFF'
fi
$CMAKE "$CMAKE_OPTS" -DCMAKE_INSTALL_PREFIX=$MY -DPREFER_EXTERNAL_LZ4=ON -DPREFER_EXTERNAL_ZLIB=ON -DPREFER_EXTERNAL_ZSTD=ON \
-DLZ4_INCLUDE_DIR=$MY/include -DLZ4_LIBRARY=$MY/lib/liblz4.a -DZSTD_INCLUDE_DIR=$MY/include -DZSTD_LIBRARY=$MY/lib/libzstd.a \
-DCMAKE_C_FLAGS="$LOCAL_CFLAGS -I$MY/include" -DCMAKE_EXE_LINKER_FLAGS="-L$MY/lib" -DZLIB_ROOT=$MY -DLZ4_ROOT=$MY -DZstd_ROOT=$MY \
$CMAKE_DEACTIVATE_X86_64 $CMAKE_NO_TESTS  -S .. -B .
cmake --build . --clean-first --verbose
if [ -n "$TESTCOMP" ]; then
    ctest --verbose
fi
cmake --install .

CB_ANY_FILES="$MY/lib/libblosc?${LIBEXT}*"
if [ -n "$CB_ANY_FILES" ]; then
  rm -f $CB_ANY_FILES
fi
CB_LIB64_FILE="$MY/lib64/libblosc.a"
if [ -f "$CB_LIB64_FILE" ]; then
  cp -p "$CB_LIB64_FILE" $MY/lib/
fi
popd
popd

popd

