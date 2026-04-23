#!/bin/bash

source settings.sh

CUDNN_ARCH=sbsa

module load nvhpc/$NVHPC_VERSION

for i in "${!CUDNN_VERSIONS[@]}"
do
    CUDNN_VERSION=${CUDNN_VERSIONS[i]}
    CUDNN_BUILD=${CUDNN_BUILDS[i]}          # e.g. "cuda13"
    CUDNN_MODULE_VERSION=${CUDNN_VERSION}_${CUDNN_BUILD}

    CUDA_MAJOR_VERSION=${CUDNN_BUILD#cuda}
    CUDNN_ARCHIVE=cudnn-linux-${CUDNN_ARCH}-${CUDNN_VERSION}_${CUDNN_BUILD}-archive
    CUDNN_INSTALL_PREFIX=$INSTALL_PREFIX/cudnn-${CUDNN_MODULE_VERSION}
    CUDNN_MODULE_PREFIX=$MODULE_PREFIX/cudnn

    if [[ -f "$CUDNN_INSTALL_PREFIX/include/cudnn.h" ]]; then
        echo "cuDNN $CUDNN_MODULE_VERSION already installed. Skipping."
        continue
    fi

    rm -rf "$CUDNN_INSTALL_PREFIX"
    cd $BUILD_PREFIX

    rm -f ${CUDNN_ARCHIVE}.tar.xz ${CUDNN_ARCHIVE}.tar.xz.*
    wget https://developer.download.nvidia.com/compute/cudnn/redist/cudnn/linux-${CUDNN_ARCH}/$CUDNN_ARCHIVE.tar.xz
    tar -xf ${CUDNN_ARCHIVE}.tar.xz

    mkdir -p $CUDNN_INSTALL_PREFIX
    mv $CUDNN_ARCHIVE/* $CUDNN_INSTALL_PREFIX/.
    rm -rf $CUDNN_ARCHIVE*

    MODULE_TEMP_PATH="$MODULE_TEMP_PREFIX/$CUDNN_MODULE_VERSION.lua"
    cp $SETUP_PREFIX/modules/cudnn_module "$MODULE_TEMP_PATH"
    sed -i "s|CUDNNVERSION|$CUDNN_MODULE_VERSION|g" "$MODULE_TEMP_PATH"
    sed -i "s|NVHPCVERSION|$NVHPC_VERSION|g"        "$MODULE_TEMP_PATH"
    sed -i "s|CUDAVERSION|$CUDA_MAJOR_VERSION|g"    "$MODULE_TEMP_PATH"
    sed -i "s|CUDNNROOT|$CUDNN_INSTALL_PREFIX|g"    "$MODULE_TEMP_PATH"

    mkdir -p $CUDNN_MODULE_PREFIX
    mv "$MODULE_TEMP_PATH" $CUDNN_MODULE_PREFIX/.
done

module unload nvhpc/$NVHPC_VERSION
