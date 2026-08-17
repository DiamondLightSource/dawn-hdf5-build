# 

HDF5_VER=2.2.0
HDF5_CHK=1a1ab8209b35586fbc1aa279ba76d102130b95badcb20ca329587219112d8c16
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
