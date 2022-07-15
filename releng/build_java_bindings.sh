#!/bin/bash
set -e -x

# docker run -it -env="ARCH=x86_64" --env="PLAT_OS=linux" -v $(pwd):/io:Z ghcr.io/diamondlightsource/manylinux-dls-2014_x86_64:latest /bin/bash /releng/build_linux_bindings.sh

. releng/build_codecs.sh
. releng/build_hdf5.sh
. releng/build_filters.sh

