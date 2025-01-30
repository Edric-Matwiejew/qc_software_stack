#!/bin/bash

source settings.sh

MPI4PY_VERSION=4.01
CUPY_VERSION=13.2.0

module load gcc
module load cmake
module load ninja
module load hpcx-mt-ompi
module load nvhpc/$NVHPC_VERSION

CUDA_MAJOR_VERSION=$(nvcc --version | grep -o "release [0-9]\+\.[0-9]\+" | awk '{split($2, a, "."); print a[1]}')

CUDA_PATH=$NVHPC_ROOT/cuda
CC=$(which gcc)
CXX=$(which g++)

for PYTHON_VERSION in "${PYTHON_VERSIONS[@]}"
do
	module load py-$PYTHON_VERSION-cupy/$CUPY_VERSION

	MPI4PY_INSTALL_PREFIX="$INSTALL_PREFIX/py-$PYTHON_VERSION-mpi4py-${MPI4PY_VERSION}"
	MPI4PY_MODULE_PREFIX="$MODULE_PREFIX/py-$PYTHON_VERSION-mpi4py"

	PYTHONPATH=$MPI4PY_INSTALL_PREFIX/lib/python${PYTHON_VERSION:0:4}/site-packages:$PYTHONPATH
	PATH=$MPI4PY_INSTALL_PREFIX/bin:$PATH

	cd $BUILD_PREFIX
	rm -rf mpi4py
	git clone --depth 1 --branch=$MPI4PY_VERSION https://github.com/mpi4py/mpi4py
	cd mpi4py

	python setup.py build

	PYTHONUSERBASE="$MPI4PY_INSTALL_PREFIX" python -m pip install --user --force-reinstall .

	cd $BUILD_PREFIX
	
	MODULE_TEMP_PATH="$BUILD_PREFIX/$MPI4PY_VERSION.lua"
	cp $SETUP_PREFIX/modules/mpi4py_module $MODULE_TEMP_PATH
	sed -i "s|MPI4PYVERSION|$MPI4PY_VERSION|g" "$MODULE_TEMP_PATH"
	sed -i "s|CUDAVERSION|$CUDA_MAJOR_VERSION|g" "$MODULE_TEMP_PATH"
	sed -i "s|NVHPCVERSION|$NVHPC_VERSION|g" "$MODULE_TEMP_PATH"
	sed -i "s|PYTHONVERSION_MAJOR_MINOR|${PYTHON_VERSION:0:4}|g" "$MODULE_TEMP_PATH"
	sed -i "s|PYTHONVERSION|$PYTHON_VERSION|g" "$MODULE_TEMP_PATH"
	sed -i "s|MPI4PYROOT|$MPI4PY_INSTALL_PREFIX|g" "$MODULE_TEMP_PATH"
	mkdir -p $MPI4PY_MODULE_PREFIX
	cat $MODULE_TEMP_PATH
	mv $MODULE_TEMP_PATH $MPI4PY_MODULE_PREFIX/.
	
done



