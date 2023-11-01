# 

HDF5_SER=1.14
HDF5_VER=${HDF5_SER}.3
HDF5_CHK=9425f224ed75d1280bb46d6f26923dd938f9040e7eaebf57e66ec7357c08f917
HDF5_DIR=hdf5-${HDF5_VER}
HDF5_TAR=${HDF5_DIR}.tar.bz2

if [ ! -f ${HDF5_TAR} ]; then

  curl -fsSLO "https://support.hdfgroup.org/ftp/HDF5/releases/hdf5-${HDF5_SER}/hdf5-${HDF5_VER}/src/${HDF5_TAR}"
  echo "${HDF5_CHK} ${HDF5_TAR}" | sha256sum -c -

fi

if [ ! -d "${HDF5_DIR}" ]; then
  tar xjf "${HDF5_TAR}"
  pushd "${HDF5_DIR}"

  ln -s ../releng .
  patch -p1 < releng/javacmake.patch
  patch -p1 < releng/hdf5-H5.patch
  popd
fi

export HDF5_SRC="${PWD}/${HDF5_DIR}"
