#!/bin/bash

source settings.sh

module load gcc/$GCC_VERSION
module load cmake/$CMAKE_VERSION
module load ninja/$NINJA_VERSION
module load hpcx-mt-ompi
module load nvhpc/$NVHPC_VERSION
module load cuquantum/$QISKIT_AER_CUQUANTUM_VERSION
module load cutensor/$QISKIT_AER_CUTENSOR_VERSION

CUDA_MAJOR_VERSION=$(nvcc --version | grep -o "release [0-9]\+\.[0-9]\+" | awk '{split($2, a, "."); print a[1]}')

CUDA_PATH=$NVHPC_ROOT/cuda
CC=$(which gcc)
CXX=$(which g++)

for PYTHON_VERSION in "${PYTHON_VERSIONS[@]}"
do
	module load py-$PYTHON_VERSION-cupy/$CUPY_VERSION

	QISKIT_AER_INSTALL_PREFIX="$INSTALL_PREFIX/py-$PYTHON_VERSION-qiskit-aer-${QISKIT_AER_VERSION}"
	QISKIT_AER_MODULE_PREFIX="$MODULE_PREFIX/py-$PYTHON_VERSION-qiskit-aer"

	if [[ -d "$QISKIT_AER_INSTALL_PREFIX/lib/python${PYTHON_VERSION:0:4}/site-packages/qiskit_aer" ]]; then
		echo "Qiskit Aer $QISKIT_AER_VERSION for Python $PYTHON_VERSION already installed. Skipping."
		continue
	fi

	# Clean up any partial install
	rm -rf "$QISKIT_AER_INSTALL_PREFIX"

	PYTHONPATH=$QISKIT_AER_INSTALL_PREFIX/lib/python${PYTHON_VERSION:0:4}/site-packages:$PYTHONPATH
	PATH=$QISKIT_AER_INSTALL_PREFIX/bin:$PATH

	cd $BUILD_PREFIX
	rm -rf qiskit-aer
	git clone --depth 1 --branch=$QISKIT_AER_VERSION https://github.com/Qiskit/qiskit-aer
	cd qiskit-aer

	# qiskit-aer 0.17.2 still inherits from thrust::{unary,binary}_function, removed
	# in Thrust 2.x. Re-inject them after wrap_thrust.hpp so THRUST_VERSION is defined.
	AER_SHIM=$BUILD_PREFIX/_aer_thrust_shim.txt
	cat > "$AER_SHIM" <<'EOF'
#if defined(THRUST_VERSION) && THRUST_VERSION >= 200000
namespace thrust {
template <typename Arg, typename Result>
struct unary_function {
  typedef Arg argument_type;
  typedef Result result_type;
};
template <typename Arg1, typename Arg2, typename Result>
struct binary_function {
  typedef Arg1 first_argument_type;
  typedef Arg2 second_argument_type;
  typedef Result result_type;
};
}
#endif
EOF
	sed -i '\|#include "misc/wrap_thrust.hpp"|r '"$AER_SHIM" \
		src/simulators/statevector/chunk/thrust_kernels.hpp

	# AER_CUDA_ARCH goes into legacy FindCUDA which only accepts dotted form (not "90").
	export AER_CUDA_ARCH="9.0"

	PYTHONUSERBASE="$QISKIT_AER_INSTALL_PREFIX" python -m pip install --user --force-reinstall scikit-build>=0.11.0
	PYTHONUSERBASE="$QISKIT_AER_INSTALL_PREFIX" python -m pip install --user --force-reinstall conan==1.65.0
	PYTHONUSERBASE="$QISKIT_AER_INSTALL_PREFIX" python -m pip install --user --force-reinstall "pybind11<2.13"
	PYTHONUSERBASE="$QISKIT_AER_INSTALL_PREFIX" python -m pip install --user --force-reinstall numpy==2.0.1

	export CONAN_USER_HOME=$BUILD_PREFIX/conan
	mkdir $CONAN_USER_HOME

	# CCCL (via CUDA 13 toolkit) needs C++17; Conan 1's spdlog/fmt recipes inject
	# -std=c++14. CMAKE_{CXX,CUDA}_STANDARD=17 makes CMake append the later -std=c++17.
	python ./setup.py bdist_wheel -vvv -- \
		-DAER_THRUST_BACKEND=CUDA \
		-DCUQUANTUM_ROOT=$CUQUANTUM_ROOT \
		-DCUTENSOR_ROOT=$CUTENSOR_ROOT \
		-DAER_MPI=True \
		-DAER_ENABLE_CUQUANTUM=true \
		-DCMAKE_CUDA_ARCHITECTURES=90 \
		-DCMAKE_CXX_STANDARD=17 \
		-DCMAKE_CUDA_STANDARD=17 \
		-DCMAKE_CXX_STANDARD_REQUIRED=ON \
		-DCMAKE_CUDA_STANDARD_REQUIRED=ON --

	PYTHONUSERBASE="$QISKIT_AER_INSTALL_PREFIX" python -m pip install --user --force-reinstall dist/qiskit_aer*.whl

	rm -rf $CONAN_USER_HOME

	cd $BUILD_PREFIX
	
	MODULE_TEMP_PATH="$BUILD_PREFIX/$QISKIT_AER_VERSION.lua"
	cp $SETUP_PREFIX/modules/qiskit_aer_module $MODULE_TEMP_PATH
	sed -i "s|QISKITAERVERSION|$QISKIT_AER_VERSION|g" "$MODULE_TEMP_PATH"
	sed -i "s|GCCVERSION|$GCC_VERSION|g" "$MODULE_TEMP_PATH"
	sed -i "s|CUDAVERSION|$CUDA_MAJOR_VERSION|g" "$MODULE_TEMP_PATH"
	sed -i "s|NVHPCVERSION|$NVHPC_VERSION|g" "$MODULE_TEMP_PATH"
	sed -i "s|CUQUANTUMVERSION|$QISKIT_AER_CUQUANTUM_VERSION|g" "$MODULE_TEMP_PATH"
	sed -i "s|CUTENSORVERSION|$QISKIT_AER_CUTENSOR_VERSION|g" "$MODULE_TEMP_PATH"
	sed -i "s|PYTHONVERSION_MAJOR_MINOR|${PYTHON_VERSION:0:4}|g" "$MODULE_TEMP_PATH"
	sed -i "s|PYTHONVERSION|$PYTHON_VERSION|g" "$MODULE_TEMP_PATH"
	sed -i "s|QISKITAERROOT|$QISKIT_AER_INSTALL_PREFIX|g" "$MODULE_TEMP_PATH"
	mkdir -p $QISKIT_AER_MODULE_PREFIX
	cat $MODULE_TEMP_PATH
	mv $MODULE_TEMP_PATH $QISKIT_AER_MODULE_PREFIX/.
	
done



