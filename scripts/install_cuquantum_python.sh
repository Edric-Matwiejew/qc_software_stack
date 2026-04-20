#!/bin/bash

source settings.sh

for PYTHON_VERSION in "${PYTHON_VERSIONS[@]}"
do


        py_major=$(echo "$PYTHON_VERSION" | cut -d. -f1)
        py_minor=$(echo "$PYTHON_VERSION" | cut -d. -f2)

        # Skip any version < 3.11
        if (( py_major < 3 )) || (( py_major == 3 && py_minor < 11 )); then
        	echo "Skipping Python $PYTHON_VERSION (requires >= 3.11)"
    		continue
     	fi


	module purge
	module load pawsey
	module load PrgEnv/nvhpc-gcc-mpi/$NVHPC_VERSION
	module load python/$PYTHON_VERSION
	module load py-$PYTHON_VERSION-mpi4py/$MPI4PY_VERSION
	python --version

        CUDA_MAJOR_VERSION=$(nvcc --version | grep -o "release [0-9]\+\.[0-9]\+" | awk '{split($2, a, "."); print a[1]}')
	CUQUANTUM_PYTHON_INSTALL_PREFIX="$INSTALL_PREFIX/py-$PYTHON_VERSION-cuquantum-${CUQUANTUM_PYTHON_VERSION}"
	CUQUANTUM_PYTHON_MODULE_PREFIX="$MODULE_PREFIX/py-$PYTHON_VERSION-cuquantum"

	if [[ -d "$CUQUANTUM_PYTHON_INSTALL_PREFIX/lib/python${PYTHON_VERSION:0:4}/site-packages/cuquantum" ]]; then
		echo "cuQuantum Python $CUQUANTUM_PYTHON_VERSION for Python $PYTHON_VERSION already installed. Skipping."
		continue
	fi

	mkdir -p $CUQUANTUM_PYTHON_INSTALL_PREFIX

	PYTHONPATH=$CUQUANTUM_PYTHON_INSTALL_PREFIX/lib/python${PYTHON_VERSION:0:4}/site-packages:$PYTHONPATH
	PATH=$CUQUANTUM_PYTHON_INSTALL_PREFIX/bin:$PATH

	PYTHONUSERBASE=$CUQUANTUM_PYTHON_INSTALL_PREFIX python3 -m pip install -v --no-cache-dir --user nvmath-python[cu13-distributed]
	PYTHONUSERBASE=$CUQUANTUM_PYTHON_INSTALL_PREFIX python3 -m pip install -v --no-cache-dir --user cuda-python[cu13]

	# Pinned to $CUQUANTUM_PYTHON_VERSION; newer (26.x) wheels ship the deprecated
	# cuTensorNet path that breaks qiskit-aer.
	PYTHONUSERBASE=$CUQUANTUM_PYTHON_INSTALL_PREFIX python3 -m pip install -vv --no-cache-dir --user cuquantum-cu$CUDA_MAJOR_VERSION==$CUQUANTUM_PYTHON_VERSION
	PYTHONUSERBASE=$CUQUANTUM_PYTHON_INSTALL_PREFIX python3 -m pip install -vv --no-cache-dir --user cuquantum-python-cu$CUDA_MAJOR_VERSION==$CUQUANTUM_PYTHON_VERSION
	

	cd $BUILD_PREFIX
	
	MODULE_TEMP_PATH="$BUILD_PREFIX/$CUQUANTUM_PYTHON_VERSION.lua"
	cp $SETUP_PREFIX/modules/cuquantum_python_module $MODULE_TEMP_PATH
	sed -i "s|CUQUANTUM_PYTHONVERSION|$CUQUANTUM_PYTHON_VERSION|g" "$MODULE_TEMP_PATH"
	sed -i "s|CUDAVERSION|$CUDA_MAJOR_VERSION|g" "$MODULE_TEMP_PATH"
	sed -i "s|GCCVERSION|$GCC_VERSION|g" "$MODULE_TEMP_PATH"
	sed -i "s|CUPYVERSION|$CUPY_VERSION|g" "$MODULE_TEMP_PATH"
	sed -i "s|NVHPCVERSION|$NVHPC_VERSION|g" "$MODULE_TEMP_PATH"
	sed -i "s|CUQUANTUMPYTHONROOT|$CUQUANTUM_PYTHON_INSTALL_PREFIX|g" "$MODULE_TEMP_PATH"
	sed -i "s|PYTHONVERSION_MAJOR_MINOR|${PYTHON_VERSION:0:4}|g" "$MODULE_TEMP_PATH"
	sed -i "s|PYTHONVERSION|$PYTHON_VERSION|g" "$MODULE_TEMP_PATH"
	# Template has no CUQUANTUMVERSION placeholder — cuquantum-python wheel
	# ships its own shared libs and doesn't load() a C SDK module.
	sed -i "s|CUTENSORVERSION|$CUTENSOR_VERSION|g" "$MODULE_TEMP_PATH"
	mkdir -p $CUQUANTUM_PYTHON_MODULE_PREFIX
	mv $MODULE_TEMP_PATH $CUQUANTUM_PYTHON_MODULE_PREFIX/.
	

done

module purge
module load pawsey
