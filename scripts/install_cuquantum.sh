#!/bin/bash

source settings.sh

CUQUANTUM_ARCH=sbsa

module load hpcx-mt-ompi
module load nvhpc/$NVHPC_VERSION
module load gcc/$GCC_VERSION

CUDA_MAJOR_VERSION=$(nvcc --version | grep -o "release [0-9]\+\.[0-9]\+" | awk '{split($2, a, "."); print a[1]}')

cd $BUILD_PREFIX

for i in "${!CUQUANTUM_VERSIONS[@]}"; do
    CUQUANTUM_VERSION=${CUQUANTUM_VERSIONS[$i]}
    CUQUANTUM_BUILD=${CUQUANTUM_BUILD_NUMBER[$i]}
    CUQUANTUM_INSTALL_PREFIX=$INSTALL_PREFIX/cuquantum-${CUQUANTUM_VERSION}
    CUQUANTUM_MODULE_PATH=$MODULE_PREFIX/cuquantum/$CUQUANTUM_VERSION.lua
    CUQUANTUM_ARCHIVE=cuquantum-linux-${CUQUANTUM_ARCH}-${CUQUANTUM_VERSION}.${CUQUANTUM_BUILD}-archive

    module load cutensor/$CUTENSOR_VERSION
    
    # Check if already installed
    if [[ -d "$CUQUANTUM_INSTALL_PREFIX" ]]; then
        echo "cuQuantum $CUQUANTUM_VERSION (Build $CUQUANTUM_BUILD) already installed. Skipping."
        continue
    fi
    
    echo "Installing cuQuantum $CUQUANTUM_VERSION (Build $CUQUANTUM_BUILD)"
    wget https://developer.download.nvidia.com/compute/cuquantum/redist/cuquantum/linux-${CUQUANTUM_ARCH}/$CUQUANTUM_ARCHIVE.tar.xz
    tar -xvf $CUQUANTUM_ARCHIVE.tar.xz
    
    # Build MPI shared library
    cd $CUQUANTUM_ARCHIVE/distributed_interfaces
    $(which gcc) -shared -std=c99 -fPIC \
        -I${NVHPC_ROOT}/cuda/include -I../include -I${MPI_HOME}/include \
        cutensornet_distributed_interface_mpi.c \
        -L${MPI_HOME}/lib -lmpi \
        -o libcutensornet_distributed_interface_mpi.so
	    
    cd $BUILD_PREFIX
    
    # Install cuQuantum
    mkdir -p $CUQUANTUM_INSTALL_PREFIX
    mv $CUQUANTUM_ARCHIVE/* $CUQUANTUM_INSTALL_PREFIX/.
    rm -rf $CUQUANTUM_ARCHIVE.tar.xz
    
    # Setup module file
    MODULE_TEMP_PATH="$BUILD_PREFIX/$CUQUANTUM_VERSION.lua"
    cp $SETUP_PREFIX/modules/cuquantum_module $MODULE_TEMP_PATH
    sed -i "s|CUQUANTUMVERSION|$CUQUANTUM_VERSION|g" "$MODULE_TEMP_PATH"
    sed -i "s|GCCVERSION|$GCC_VERSION|g" "$MODULE_TEMP_PATH"
    sed -i "s|CUDAVERSION|$CUDA_MAJOR_VERSION|g" "$MODULE_TEMP_PATH"
    sed -i "s|CUTENSORVERSION|$CUTENSOR_VERSION|g" "$MODULE_TEMP_PATH"
    sed -i "s|NVHPCVERSION|$NVHPC_VERSION|g" "$MODULE_TEMP_PATH"
    sed -i "s|CUQUANTUMROOT|$CUQUANTUM_INSTALL_PREFIX|g" "$MODULE_TEMP_PATH"
    mkdir -p $MODULE_PREFIX/cuquantum
    mv $MODULE_TEMP_PATH $CUQUANTUM_MODULE_PATH

done

module unload cutensor/$CUTENSOR_VERSION
module unload hpcx-mt-ompi
module unload nvhpc/$NVHPC_VERSION

