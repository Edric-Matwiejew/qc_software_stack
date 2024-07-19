#!/bin/bash

source settings.sh

# version and build from download URL at https://developer.nvidia.com/cutensor-downloads
CUTENSOR_ARCH=sbsa
CUTENSOR_VERSION=2.0.1
CUTENSOR_BUILD=2

module load nvhpc/$NVHPC_VERSION
CUDA_MAJOR_VERSION=$(nvcc --version | grep -o "release [0-9]\+\.[0-9]\+" | awk '{split($2, a, "."); print a[1]}')

CUTENSOR_ARCHIVE=libcutensor-linux-${CUTENSOR_ARCH}-${CUTENSOR_VERSION}.${CUTENSOR_BUILD}-archive
CUTENSOR_INSTALL_PREFIX=$INSTALL_PREFIX/cutensor-${CUTENSOR_VERSION}
CUTENSOR_MODULE_PREFIX=$MODULE_PREFIX/cutensor-${CUDA_MAJOR_VERSION}

cd $BUILD_PREFIX

# download and extract archive
wget https://developer.download.nvidia.com/compute/cutensor/redist/libcutensor/linux-${CUTENSOR_ARCH}/$CUTENSOR_ARCHIVE.tar.xz
tar -xvf ${CUTENSOR_ARCHIVE}.tar.xz

# install
mkdir -p $CUTENSOR_INSTALL_PREFIX
mv $CUTENSOR_ARCHIVE/* $CUTENSOR_INSTALL_PREFIX/.

# clean up build files
rm -rf $CUTENSOR_ARCHIVE*

# create module from template
MODULE_TEMP_PATH="$MODULE_TEMP_PREFIX/$CUTENSOR_VERSION"
cp $SETUP_PREFIX/modules/cutensor_module "$MODULE_TEMP_PATH"
sed -i "s|CUTENSORVERSION|$CUTENSOR_VERSION|g" "$MODULE_TEMP_PATH"
sed -i "s|CUDAVERSION|$CUDA_MAJOR_VERSION|g" "$MODULE_TEMP_PATH"
sed -i "s|CUTENSORROOT|$CUTENSOR_INSTALL_PREFIX|g" "$MODULE_TEMP_PATH"

# install module
mkdir -p $CUTENSOR_MODULE_PREFIX
mv "$MODULE_TEMP_PATH" $CUTENSOR_MODULE_PREFIX/$CUTENSOR_VERSION

module unload nvhpc/$NVHPC_VERSION

