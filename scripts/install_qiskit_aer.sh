#!/bin/bash

source settings.sh

QISKIT_AER_VERSION=0.15
CUPY_VERSION=13.2.0
CUQUANTUM_VERSION=24.03.0

module load cmake
module load ninja
module load nvhpc/$NVHPC_VERSION
module load cuquantum/$CUQUANTUM_VERSION

CUDA_MAJOR_VERSION=$(nvcc --version | grep -o "release [0-9]\+\.[0-9]\+" | awk '{split($2, a, "."); print a[1]}')

CUDA_PATH=$NVHPC_ROOT/cuda
CC=$HOST_CC
CXX=$HOST_CXX

for PYTHON_VERSION in "${PYTHON_VERSIONS[@]}"
do
	module load py-$PYTHON_VERSION-cupy/$CUPY_VERSION

	QISKIT_AER_INSTALL_PREFIX="$INSTALL_PREFIX/py-$PYTHON_VERSION-qiskit-aer-${QISKIT_AER_VERSION}"
	QISKIT_AER_MODULE_PREFIX="$MODULE_PREFIX/py-$PYTHON_VERSION-qiskit-aer"

	PYTHONPATH=$QISKIT_AER_INSTALL_PREFIX/lib/python${PYTHON_VERSION:0:4}/site-packages:$PYTHONPATH
	PATH=$QISKIT_AER_INSTALL_PREFIX/bin:$PATH

	cd $BUILD_PREFIX
	rm -rf qiskit-aer
	git clone --depth 1 --branch=$QISKIT_AER_VERSION https://github.com/Qiskit/qiskit-aer
	cd qiskit-aer

	PYTHONUSERBASE="$QISKIT_AER_INSTALL_PREFIX" python -m pip install --user --force-reinstall -vvv scikit-build>=0.11.0
	PYTHONUSERBASE="$QISKIT_AER_INSTALL_PREFIX" python -m pip install --user --force-reinstall -vv conan==1.65.0
	PYTHONUSERBASE="$QISKIT_AER_INSTALL_PREFIX" python -m pip install --user --force-reinstall -vv pybind11==2.13.4
	PYTHONUSERBASE="$QISKIT_AER_INSTALL_PREFIX" python -m pip install --user --force-reinstall -vv numpy==2.0.1

	export CONAN_USER_HOME=$BUILD_PREFIX/conan
	mkdir $CONAN_USER_HOME

	python ./setup.py bdist_wheel -vvv -- \
		-DAER_THRUST_BACKEND=CUDA \
		-DCUQUANTUM_ROOT=$CUQUANTUM_ROOT \
		-DCUTENSOR_ROOT=$CUTENSOR_ROOT \
		-DAER_ENABLE_CUQUANTUM=true --		

	PYTHONUSERBASE="$QISKIT_AER_INSTALL_PREFIX" python -m pip install --user --force-reinstall dist/qiskit_aer*.whl

	rm -rf $CONAN_USER_HOME

	cd $BUILD_PREFIX
	
	MODULE_TEMP_PATH="$BUILD_PREFIX/$QISKIT_AER_VERSION.lua"
	cp $SETUP_PREFIX/modules/qiskit_aer_module $MODULE_TEMP_PATH
	sed -i "s|QISKITAERVERSION|$QISKIT_AER_VERSION|g" "$MODULE_TEMP_PATH"
	sed -i "s|CUDAVERSION|$CUDA_MAJOR_VERSION|g" "$MODULE_TEMP_PATH"
	sed -i "s|NVHPCVERSION|$NVHPC_VERSION|g" "$MODULE_TEMP_PATH"
	sed -i "s|CUQUANTUMVERSION|$CUQUANTUM_VERSION|g" "$MODULE_TEMP_PATH"
	sed -i "s|PYTHONVERSION|$PYTHON_VERSION|g" "$MODULE_TEMP_PATH"
	sed -i "s|PYTHONVERSION_MAJOR_MINOR|${PYTHON_VERSION:0:4}|g" "$MODULE_TEMP_PATH"
	sed -i "s|QISKITAERROOT|$QISKIT_AER_INSTALL_PREFIX|g" "$MODULE_TEMP_PATH"
	mkdir -p $QISKIT_AER_MODULE_PREFIX
	cat $MODULE_TEMP_PATH
	mv $MODULE_TEMP_PATH $QISKIT_AER_MODULE_PREFIX/.
	
done



