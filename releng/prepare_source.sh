# 

HDF5_VER=1.14.5
HDF5_CHK=ec2e13c52e60f9a01491bb3158cb3778c985697131fc6a342262d32a26e58e44
HDF5_DIR=hdf5-${HDF5_VER}
HDF5_TGZ=${HDF5_DIR}.tar.gz

if [ ! -f ${HDF5_TGZ} ]; then
  curl -fsSLO "https://github.com/HDFGroup/hdf5/releases/download/hdf5_${HDF5_VER}/${HDF5_TGZ}"
  echo "${HDF5_CHK} ${HDF5_TGZ}" | sha256sum -c -
fi

if [ ! -d "${HDF5_DIR}" ]; then
  tar xzf "${HDF5_TGZ}"
  pushd "${HDF5_DIR}"

  ln -s ../releng .
  patch -p1 < releng/javacmake.patch
  patch -p1 < releng/hdf5-H5.patch
  patch -p1 < releng/hdf5-win32-msys.patch
  popd
fi

export HDF5_SRC="${PWD}/${HDF5_DIR}"
