#!/bin/bash

source settings.sh

CUPY_VERSION=13.2.0
CUPY_GIT_TAG=v13
CUTENSOR_VERSION=2.0.1

module load gcc

# Build against the toolchain used to build Python
PYTHON_C_COMPILER=$(which gcc)
PYTHON_CXX_COMPILER=$(which g++)

module load nvhpc/$NVHPC_VERSION
module load cutensor-12/$CUTENSOR_VERSION

CUDA_MAJOR_MINOR_VERSION=$(nvcc --version | grep -o "release [0-9]\+\.[0-9]\+" | awk '{split($2, a, "."); print a[1] "." a[2]}')
	
# Specify the version of nvcc that comes with nvhpc
NVCC=$(which nvcc)

export CUDA_PATH=$NVHPC_ROOT/cuda

# Need to specify the include and library paths explicitly
export CFLAGS="-I$NVHPC_ROOT/cuda/include \
               -I$NVHPC_ROOT/math_libs/include \
               -I$NVHPC_ROOT/cuda/$CUDA_MAJOR_MINOR_VERSION/targets/x86_64-linux/include \
	       -I$CUTENSOR_ROOT/include"

export LDFLAGS="-L$NVHPC_ROOT/cuda/lib64 \
                -L$NVHPC_ROOT/math_libs/lib64 \
                -L$NVHPC_ROOT/REDIST/comm_libs/$CUDA_MAJOR_MINOR_VERSION/nccl/lib \
                -L$NVHPC_ROOT/cuda/$CUDA_MAJOR_MINOR_VERSION/targets/x86_64-linux/lib/stubs \
	       	-L$CUTENSOR_ROOT/lib"

# The CuPy build module doesn't pull in the CFLAGS or LDFLAGS variables
CC="$PYTHON_C_COMPILER $CFLAGS $LDFLAGS"
CXX="$PYTHON_CXX_COMPILER $CFLAGS $LDFLAGS"

cd $BUILD_PREFIX

for PYTHON_VERSION in "${PYTHON_VERSIONS[@]}"
do

	CUPY_INSTALL_PREFIX="$INSTALL_PREFIX/py-$PYTHON_VERSION-cupy-$CUPY_VERSION"
	CUPY_MODULE_PREFIX="$MODULE_PREFIX/py-$PYTHON_VERSION-cupy"

	module load python/$PYTHON_VERSION
	# Install CuPy
	mkdir -p $CUPY_INSTALL_PREFIX
	
	rm -rf cupy
	git clone --branch=$CUPY_GIT_TAG --recursive https://github.com/cupy/cupy
	
	# only way to exclude the system install of cudnn!?
	sed -i '/_from_dict(CUDA_cudnn, ctx),/d' cupy/install/cupy_builder/_features.py
	
	cd cupy
	PYTHONUSERBASE="$CUPY_INSTALL_PREFIX" python3 -m pip install -v --user .
	
	cd $BUILD_PREFIX
	
	MODULE_TEMP_PATH="$BUILD_PREFIX/$CUPY_VERSION.lua"
	cp $SETUP_PREFIX/modules/cupy_module $MODULE_TEMP_PATH
	sed -i "s|CUPYVERSION|$CUPY_VERSION|g" "$MODULE_TEMP_PATH"
	sed -i "s|CUDAVERSION|$CUDA_MAJOR_MINOR_VERSION|g" "$MODULE_TEMP_PATH"
	sed -i "s|NVHPCVERSION|$NVHPC_VERSION|g" "$MODULE_TEMP_PATH"
	sed -i "s|CUPYROOT|$CUPY_INSTALL_PREFIX|g" "$MODULE_TEMP_PATH"
	sed -i "s|PYTHONVERSION_MAJOR_MINOR|${PYTHON_VERSION:0:4}|g" "$MODULE_TEMP_PATH"
	sed -i "s|PYTHONVERSION|$PYTHON_VERSION|g" "$MODULE_TEMP_PATH"
	sed -i "s|CUDAPATH|$CUDA_PATH|g" "$MODULE_TEMP_PATH"
	mkdir -p $CUPY_MODULE_PREFIX
	mv $MODULE_TEMP_PATH $CUPY_MODULE_PREFIX/.
	
	module unload python/$PYTHON_VERSION

done

module unload cutensor-12/$CUTENSOR_VERSION
module unload nvhpc
