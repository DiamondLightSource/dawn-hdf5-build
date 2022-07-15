#!/bin/bash

# external filter plugin repo
FP_BRANCH=dls_build
# bitshuffle repo
BS_BRANCH=use-hdf5-memory-calls

pushd $MS

if [ ! -d HDF5-External-Filter-Plugins.git ]; then
    # checkout plugins
    git clone --depth 2 -b $FP_BRANCH https://github.com/DiamondLightSource/HDF5-External-Filter-Plugins.git HDF5-External-Filter-Plugins.git
fi
pushd HDF5-External-Filter-Plugins.git

if [ ! -d bitshuffle.git ]; then
    # checkout plugins
    git clone --depth 2 -b $BS_BRANCH https://github.com/DiamondLightSource/bitshuffle.git bitshuffle.git
fi

make -f Makefile.dls clean
make -f Makefile.dls
if [ -z "$DONT_TEST_PLUGINS" ]; then
    pushd tests
    . check_plugins.sh
    popd
fi

cp lib*.${LIBEXT} $DEST

popd

