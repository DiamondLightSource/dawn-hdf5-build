# 

HDF5_VER=2.1.0
HDF5_CHK=ce7f5515a95d588b8606c3fb50643f8b88ac52ffbbde9c63bb1edca6a256e964
HDF5_DIR=hdf5-${HDF5_VER}
HDF5_TGZ=${HDF5_DIR}.tar.gz

if [ ! -f ${HDF5_TGZ} ]; then
  curl -fsSLO "https://github.com/HDFGroup/hdf5/releases/download/${HDF5_VER}/${HDF5_TGZ}"
  echo "${HDF5_CHK} ${HDF5_TGZ}" | sha256sum -c -
fi

if [ ! -d "${HDF5_DIR}" ]; then
  tar xzf "${HDF5_TGZ}"
  pushd "${HDF5_DIR}"

  ln -s ../releng .
  patch -p1 < releng/javacmake.patch
  patch -p1 < releng/hdf5-H5.patch
  popd
fi

export HDF5_SRC="${PWD}/${HDF5_DIR}"
