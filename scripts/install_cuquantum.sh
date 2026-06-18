#!/bin/bash

source settings.sh

CUQUANTUM_ARCH=sbsa

module load hpcx-mt-ompi
module load nvhpc/$NVHPC_VERSION
module load gcc/$GCC_VERSION

cd $BUILD_PREFIX

for i in "${!CUQUANTUM_VERSIONS[@]}"; do
    CUQUANTUM_VERSION=${CUQUANTUM_VERSIONS[$i]}
    CUQUANTUM_BUILD=${CUQUANTUM_BUILD_NUMBER[$i]}
    # cuda12 / cuda13 suffix; matching cutensor install shares it.
    CUDA_SUFFIX=$(echo "$CUQUANTUM_BUILD" | grep -oE 'cuda[0-9]+')
    CUDA_MAJOR_VERSION=${CUDA_SUFFIX#cuda}
    CUQUANTUM_MODULE_VERSION=${CUQUANTUM_VERSION}_${CUDA_SUFFIX}
    MATCHING_CUTENSOR_VERSION=${CUTENSOR_VERSIONS[0]}_${CUDA_SUFFIX}

    CUQUANTUM_INSTALL_PREFIX=$INSTALL_PREFIX/cuquantum-${CUQUANTUM_MODULE_VERSION}
    CUQUANTUM_MODULE_PATH=$MODULE_PREFIX/cuquantum/$CUQUANTUM_MODULE_VERSION.lua
    CUQUANTUM_ARCHIVE=cuquantum-linux-${CUQUANTUM_ARCH}-${CUQUANTUM_VERSION}.${CUQUANTUM_BUILD}-archive

    module load cutensor/$MATCHING_CUTENSOR_VERSION

    if [[ -d "$CUQUANTUM_INSTALL_PREFIX" ]]; then
        echo "cuQuantum $CUQUANTUM_MODULE_VERSION already installed. Skipping."
        module unload cutensor/$MATCHING_CUTENSOR_VERSION
        continue
    fi

    echo "Installing cuQuantum $CUQUANTUM_MODULE_VERSION (build $CUQUANTUM_BUILD)"
    cd $BUILD_PREFIX
    wget https://developer.download.nvidia.com/compute/cuquantum/redist/cuquantum/linux-${CUQUANTUM_ARCH}/$CUQUANTUM_ARCHIVE.tar.xz
    tar -xf $CUQUANTUM_ARCHIVE.tar.xz

    cd $CUQUANTUM_ARCHIVE/distributed_interfaces
    $(which gcc) -shared -std=c99 -fPIC \
        -I${NVHPC_ROOT}/cuda/include -I../include -I${MPI_HOME}/include \
        cutensornet_distributed_interface_mpi.c \
        -L${MPI_HOME}/lib -lmpi \
        -o libcutensornet_distributed_interface_mpi.so
    cd $BUILD_PREFIX

    mkdir -p $CUQUANTUM_INSTALL_PREFIX
    mv $CUQUANTUM_ARCHIVE/* $CUQUANTUM_INSTALL_PREFIX/.
    rm -rf $CUQUANTUM_ARCHIVE $CUQUANTUM_ARCHIVE.tar.xz

    MODULE_TEMP_PATH="$BUILD_PREFIX/$CUQUANTUM_MODULE_VERSION.lua"
    cp $SETUP_PREFIX/modules/cuquantum_module $MODULE_TEMP_PATH
    sed -i "s|CUQUANTUMVERSION|$CUQUANTUM_MODULE_VERSION|g" "$MODULE_TEMP_PATH"
    sed -i "s|GCCVERSION|$GCC_VERSION|g"                   "$MODULE_TEMP_PATH"
    sed -i "s|CUDAVERSION|$CUDA_MAJOR_VERSION|g"           "$MODULE_TEMP_PATH"
    sed -i "s|CUTENSORVERSION|$MATCHING_CUTENSOR_VERSION|g" "$MODULE_TEMP_PATH"
    sed -i "s|NVHPCVERSION|$NVHPC_VERSION|g"               "$MODULE_TEMP_PATH"
    sed -i "s|CUQUANTUMROOT|$CUQUANTUM_INSTALL_PREFIX|g"   "$MODULE_TEMP_PATH"
    mkdir -p $MODULE_PREFIX/cuquantum
    mv $MODULE_TEMP_PATH $CUQUANTUM_MODULE_PATH

    module unload cutensor/$MATCHING_CUTENSOR_VERSION
done

module unload hpcx-mt-ompi
module unload nvhpc/$NVHPC_VERSION

