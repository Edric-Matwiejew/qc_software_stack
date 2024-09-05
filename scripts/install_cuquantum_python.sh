#!/bin/bash

source settings.sh

CUQUANTUM_PYTHON_VERSION=24.03.0
CUPY_VERSION=13.2.0
CUTENSOR_VERSION=2.0.1
CUQUANTUM_VERSION=24.03.0

module load gcc
module load nvhpc-openmpi3/$NVHPC_VERSION
module load cuquantum/$CUQUANTUM_VERSION

CUDA_MAJOR_VERSION=$(nvcc --version | grep -o "release [0-9]\+\.[0-9]\+" | awk '{split($2, a, "."); print a[1]}')

CUDA_PATH=$NVHPC_ROOT/cuda
CC=$(which gcc)
CXX=$(which g++)

for PYTHON_VERSION in "${PYTHON_VERSIONS[@]}"
do

	module load py-$PYTHON_VERSION-cupy/$CUPY_VERSION

	CUQUANTUM_PYTHON_INSTALL_PREFIX="$INSTALL_PREFIX/py-$PYTHON_VERSION-cuquantum-${CUQUANTUM_PYTHON_VERSION}"
	CUQUANTUM_PYTHON_MODULE_PREFIX="$MODULE_PREFIX/py-$PYTHON_VERSION-cuquantum"

	PYTHONPATH=$CUQUANTUM_PYTHON_INSTALL_PREFIX/lib/python${PYTHON_VERSION:0:4}/site-packages:$PYTHONPATH
	PATH=$CUQUANTUM_PYTHON_INSTALL_PREFIX/bin:$PATH

	cd $BUILD_PREFIX

	rm -rf cuQuantum
	git clone --branch=v$CUQUANTUM_PYTHON_VERSION https://github.com/NVIDIA/cuQuantum
	cd cuQuantum/python
	
	# install prereqs
	PYTHONUSERBASE=$CUQUANTUM_PYTHON_INSTALL_PREFIX python3 -m pip install \
		-v --no-build-isolation --no-cache-dir --user \
		"cython>=0.29.22,<3" \
		"setuptools>=61.0.0" \
		"pip>=21.3.1" \
		"packaging==24.1" \
		"numpy>=1.21,<2" \
		"wheel>=0.34.0"
	
	##install cuquantum python
	PYTHONUSERBASE=$CUQUANTUM_PYTHON_INSTALL_PREFIX python3 -m pip install -v --no-cache-dir --user --no-deps .

	cd $BUILD_PREFIX
	
	MODULE_TEMP_PATH="$BUILD_PREFIX/$CUQUANTUM_PYTHON_VERSION.lua"
	cp $SETUP_PREFIX/modules/cuquantum_python_module $MODULE_TEMP_PATH
	sed -i "s|CUQUANTUM_PYTHONVERSION|$CUQUANTUM_PYTHON_VERSION|g" "$MODULE_TEMP_PATH"
	sed -i "s|CUDAVERSION|$CUDA_MAJOR_VERSION|g" "$MODULE_TEMP_PATH"
	sed -i "s|CUPYVERSION|$CUPY_VERSION|g" "$MODULE_TEMP_PATH"
	sed -i "s|NVHPCVERSION|$NVHPC_VERSION|g" "$MODULE_TEMP_PATH"
	sed -i "s|CUQUANTUMPYTHONROOT|$CUQUANTUM_PYTHON_INSTALL_PREFIX|g" "$MODULE_TEMP_PATH"
	sed -i "s|PYTHONVERSION_MAJOR_MINOR|${PYTHON_VERSION:0:4}|g" "$MODULE_TEMP_PATH"
	sed -i "s|PYTHONVERSION|$PYTHON_VERSION|g" "$MODULE_TEMP_PATH"
	sed -i "s|CUQUANTUMVERSION|$CUQUANTUM_VERSION|g" "$MODULE_TEMP_PATH"
	sed -i "s|CUTENSORVERSION|$CUTENSOR_VERSION|g" "$MODULE_TEMP_PATH"
	mkdir -p $CUQUANTUM_PYTHON_MODULE_PREFIX
	mv $MODULE_TEMP_PATH $CUQUANTUM_PYTHON_MODULE_PREFIX/.
	
	module unload py-$PYTHON_VERSION-cupy/$CUPY_VERSION
	
done

module unload cuquantum/$CUQUANTUM_VERSION
module unload nvhpc-openmpi3
