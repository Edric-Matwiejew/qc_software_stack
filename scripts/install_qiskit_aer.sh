#!/bin/bash

source settings.sh

module load gcc/$GCC_VERSION
module load cmake/$CMAKE_VERSION
module load ninja/$NINJA_VERSION
module load hpcx-mt-ompi
module load nvhpc/$NVHPC_VERSION
module load cuquantum/$CUQUANTUM_VERSION
module load cutensor/$CUTENSOR_VERSION

CUDA_MAJOR_VERSION=$(nvcc --version | grep -o "release [0-9]\+\.[0-9]\+" | awk '{split($2, a, "."); print a[1]}')

CUDA_PATH=$NVHPC_ROOT/cuda
CC=$(which gcc)
CXX=$(which g++)

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

	PYTHONUSERBASE="$QISKIT_AER_INSTALL_PREFIX" python -m pip install --user --force-reinstall scikit-build>=0.11.0
	PYTHONUSERBASE="$QISKIT_AER_INSTALL_PREFIX" python -m pip install --user --force-reinstall conan==1.65.0
	PYTHONUSERBASE="$QISKIT_AER_INSTALL_PREFIX" python -m pip install --user --force-reinstall pybind11==2.13.4
	PYTHONUSERBASE="$QISKIT_AER_INSTALL_PREFIX" python -m pip install --user --force-reinstall numpy==2.0.1

	export CONAN_USER_HOME=$BUILD_PREFIX/conan
	mkdir $CONAN_USER_HOME

	python ./setup.py bdist_wheel -vvv -- \
		-DAER_THRUST_BACKEND=CUDA \
		-DCUQUANTUM_ROOT=$CUQUANTUM_ROOT \
		-DCUTENSOR_ROOT=$CUTENSOR_ROOT \
		-DAER_MPI=True \
		-DAER_ENABLE_CUQUANTUM=true --		

	PYTHONUSERBASE="$QISKIT_AER_INSTALL_PREFIX" python -m pip install --user --force-reinstall dist/qiskit_aer*.whl

	rm -rf $CONAN_USER_HOME

	cd $BUILD_PREFIX
	
	MODULE_TEMP_PATH="$BUILD_PREFIX/$QISKIT_AER_VERSION.lua"
	cp $SETUP_PREFIX/modules/qiskit_aer_module $MODULE_TEMP_PATH
	sed -i "s|QISKITAERVERSION|$QISKIT_AER_VERSION|g" "$MODULE_TEMP_PATH"
	sed -i "s|GCCVERSION|$GCC_VERSION|g" "$MODULE_TEMP_PATH"
	sed -i "s|CUDAVERSION|$CUDA_MAJOR_VERSION|g" "$MODULE_TEMP_PATH"
	sed -i "s|NVHPCVERSION|$NVHPC_VERSION|g" "$MODULE_TEMP_PATH"
	sed -i "s|CUQUANTUMVERSION|$CUQUANTUM_VERSION|g" "$MODULE_TEMP_PATH"
	sed -i "s|CUTENSORVERSION|$CUTENSOR_VERSION|g" "$MODULE_TEMP_PATH"
	sed -i "s|PYTHONVERSION_MAJOR_MINOR|${PYTHON_VERSION:0:4}|g" "$MODULE_TEMP_PATH"
	sed -i "s|PYTHONVERSION|$PYTHON_VERSION|g" "$MODULE_TEMP_PATH"
	sed -i "s|QISKITAERROOT|$QISKIT_AER_INSTALL_PREFIX|g" "$MODULE_TEMP_PATH"
	mkdir -p $QISKIT_AER_MODULE_PREFIX
	cat $MODULE_TEMP_PATH
	mv $MODULE_TEMP_PATH $QISKIT_AER_MODULE_PREFIX/.
	
done



