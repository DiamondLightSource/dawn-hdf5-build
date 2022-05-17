#!/bin/bash
set -e -x

# docker run -it -env="ARCH=x86_64" --env="PLAT_OS=linux" -v $(pwd):/io:Z ghcr.io/diamondlightsource/manylinux-dls-2014_x86_64:latest /bin/bash /releng/build_linux_bindings.sh

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

# external filter plugin repo
FP_BRANCH=dls_build
# bitshuffle repo
BS_BRANCH=use-hdf5-memory-calls

case $ARCH in
  aarch64)
    GLOBAL_CFLAGS="-fPIC -O3 -march=armv8-a"
    ;;
  x86_64|*)
    GLOBAL_CFLAGS="-fPIC -O3 -msse4 -mavx2"
    ;;
esac

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

JBIN=$(readlink -f `which java`)
export JDKDIR=$(dirname $(dirname $(dirname $JBIN)))

MS=$BASE_DIR/build/src
export MY=$BASE_DIR/build/opt/$PLAT_OS
MA=$MY/include,$MY/lib
export H5=$BASE_DIR/build/hdf5/$PLAT_OS

mkdir -p $MS
mkdir -p $MY
mkdir -p $H5

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
cd $MS


ZLIB_SRC=zlib-$ZLIB_VER
download_check_extract_pushd $ZLIB_SRC ${ZLIB_SRC}.tar.gz $ZLIB_CHK "https://www.zlib.net"
# unpack and compile static
CFLAGS=$GLOBAL_CFLAGS ./configure --prefix=$MY --64 --static
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
CFLAGS=$GLOBAL_CFLAGS ./configure --prefix=$MY 
make clean
make install
popd


ZSTD_SRC=zstd-$ZSTD_VER
download_check_extract_pushd $ZSTD_SRC ${ZSTD_SRC}.tar.gz $ZSTD_CHK "https://github.com/facebook/zstd/releases/download/v$ZSTD_VER"
make clean
if [ -n "$TESTCOMP" ]; then
    PATH=$MY/bin:$PATH make CFLAGS="$GLOBAL_CFLAGS -I$MY/include" ZLIBLD="-L$MY/lib -lz" PREFIX=$MY test
fi
#PATH=$MY/bin:$PATH 
make CFLAGS="$GLOBAL_CFLAGS -I$MY/include" ZLIBLD="-L$MY/lib -lz" PREFIX=$MY install
rm -f $MY/lib/libzstd.${LIBEXT}*
popd



download_check_extract_pushd c-blosc-$CB_VER v${CB_VER}.tar.gz $CB_CHK "https://github.com/Blosc/c-blosc/archive/refs/tags"
mkdir -p build && cd build
#CFLAGS="$GLOBAL_CFLAGS -DNDEBUG"
if [ $ARCH == 'x64_64' ]; then
    CFLAGS="$GLOBAL_CFLAGS" $CMAKE -DCMAKE_INSTALL_PREFIX=$MY -DPREFER_EXTERNAL_LZ4=ON -DPREFER_EXTERNAL_ZLIB=ON -DPREFER_EXTERNAL_ZSTD=ON -DZLIB_ROOT=$MY -DLZ4_ROOT=$MY -DZstd_ROOT=$MY ..
else
    CFLAGS="$GLOBAL_CFLAGS" $CMAKE -DCMAKE_INSTALL_PREFIX=$MY -DPREFER_EXTERNAL_LZ4=ON -DPREFER_EXTERNAL_ZLIB=ON -DPREFER_EXTERNAL_ZSTD=ON -DZLIB_ROOT=$MY -DLZ4_ROOT=$MY -DZstd_ROOT=$MY -DDEACTIVATE_AVX2=ON ..
fi
make clean
if [ -n "$TESTCOMP" ]; then
    make VERBOSE=1 test
fi
make install
rm -f $MY/lib/libblosc.${LIBEXT}*
popd


# use checked out version; no need to unpack
pushd $CHECKOUT_DIR

mkdir -p hdf5-build-$PLAT_OS
pushd hdf5-build-$PLAT_OS
CFLAGS=$GLOBAL_CFLAGS $CHECKOUT_DIR/configure --prefix=$H5 --enable-shared=yes --disable-hl --enable-threadsafe --with-zlib=$MA --with-pic=yes --enable-optimization=-O2 --enable-unsupported --enable-java
if [ -n "$TESTCOMP" ]; then
    # not necessary on GH actions as runner is not root
    if false; then
        # remove expected exception as root can write into read-only files so no exception gets thrown (see junit-failure.txt)
        OLD_FILE=$CHECKOUT_DIR/java/test/TestH5Fbasic
        mv ${OLD_FILE}.java ${OLD_FILE}.orig
        awk '/testH5Fopen_read_only/{sub(/Test([^\n]*)/, "Test", last)} NR>1 {print last} {last=$0} END {print last}' ${OLD_FILE}.orig > ${OLD_FILE}.java
    fi
    make check
fi
make install
popd


JARFILE="$H5/lib/jarhdf5-*.jar"
VERSION=`basename $JARFILE | sed -e 's/jarhdf5-\(.*\)\.jar/\1/g'`

DEST=$DEST_DIR/$VERSION/$PLAT_OS/$ARCH
mkdir -p $DEST

cp $JARFILE $DEST
cp -H $H5/lib/libhdf5.${LIBEXT} $DEST
cp $H5/lib/libhdf5_java.${LIBEXT} $DEST
cp $H5/lib/libhdf5.setting $DEST

cd $MS

if [ -d HDF5-External-Filter-Plugins.git ]; then
    # checkout plugins
    git clone --depth 2 -b $FP_BRANCH git@github.com:DiamondLightSource/HDF5-External-Filter-Plugins.git HDF5-External-Filter-Plugins.git
fi
pushd HDF5-External-Filter-Plugins.git

if [ -d bitshuffle.git ]; then
    # checkout plugins
    git clone --depth 2 -b $BS_BRANCH git@github.com:DiamondLightSource/bitshuffle.git bitshuffle.git
fi

make -d Makefile.dls TGT_OS=$PLAT_OS TGT_ARCH=$ARCH clean
make -d Makefile.dls TGT_OS=$PLAT_OS TGT_ARCH=$ARCH
if [ -z "$DONT_TEST_PLUGINS" ]; then
    pushd tests
    . check_plugins.sh
    popd
fi

cp lib*.${LIBEXT} $DEST


