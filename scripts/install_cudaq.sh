source settings.sh

module load cmake
module load ninja
module load nvhpc/$NVHPC_VERSION
module load gcc/$GCC_VERSION 
module load hpcx-mt-ompi
module load cuquantum/$CUQUANTUM_VERSION

export CC=$(which gcc)
export CXX=$(which g++)
export FC=$(which gfortran)

export CUQUANTUM_INSTALL_PREFIX=$CUQUANTUM_ROOT
export CUTENSOR_INSTALL_PREFIX=$CUTENSOR_ROOT
export PERL_INSTALL_PREFIX=$PERL_ROOT

CUDA_MAJOR_MINOR_VERSION=$(nvcc --version | grep -o "release [0-9]\+\.[0-9]\+" | awk '{split($2, a, "."); print a[1] "." a[2]}')
export CUDA_HOME=$NVHPC_ROOT/cuda
export CUDA_PATH=$NVHPC_ROOT/cuda
export CUDACXX=$NVHPC_ROOT/compilers/bin/nvcc
		
# increase maximum open files limit
# required for CudaQ build
ulimit -n 10000

for PYTHON_VERSION in "${PYTHON_VERSIONS[@]}"
do
	module load python/$PYTHON_VERSION
	
	CUDA_QUANTUM_BUILD_PREFIX=$BUILD_PREFIX/py-$PYTHON_VERSION-cudaq-${CUDA_QUANTUM_VERSION}
	mkdir -p $CUDA_QUANTUM_BUILD_PREFIX
	
	CUDA_QUANTUM_INSTALL_PREFIX=$INSTALL_PREFIX/py-$PYTHON_VERSION-cudaq-${CUDA_QUANTUM_VERSION}
	mkdir -p $CUDA_QUANTUM_INSTALL_PREFIX
	
	CUDAQ_MODULE_PREFIX=$MODULE_PREFIX/py-$PYTHON_VERSION-cudaq
	mkdir -p $CUDAQ_MODULE_PREFIX

	CUDA_QUANTUM_PYTHON_INSTALL_PREFIX=$CUDA_QUANTUM_INSTALL_PREFIX/python
	export PYTHONPATH=$CUDA_QUANTUM_PYTHON_INSTALL_PREFIX/lib/python${PYTHON_VERSION:0:4}:$PYTHONPATH
	export PATH=$CUDA_QUANTUM_PYTHON_INSTALL_PREFIX/bin:$PATH
	
	export LLVM_INSTALL_PREFIX=$CUDA_QUANTUM_INSTALL_PREFIX/llvm
	mkdir -p $LLVM_INSTALL_PREFIX
	export PYBIND11_INSTALL_PREFIX=$CUDA_QUANTUM_INSTALL_PREFIX/pybind11
	mkdir -p $PYBIND11_INSTALL_PREFIX
	export LLVM_SOURCE=$CUDA_QUANTUM_BUILD_PREFIX/llvm-source
	mkdir -p $LLVM_SOURCE
	export CUDAQ_INSTALL_PREFIX=$CUDA_QUANTUM_INSTALL_PREFIX/cudaq
	mkdir -p $CUDAQ_INSTALL_PREFIX
	
	export BLAS_INSTALL_PREFIX=$CUDA_QUANTUM_INSTALL_PREFIX/blas
	mkdir -p $BLAS_INSTALL_PREFIX
	export ZLIB_INSTALL_PREFIX=$CUDA_QUANTUM_INSTALL_PREFIX/zlib
	mkdir -p $BLAS_INSTALL_PREFIX
	export OPENSSL_INSTALL_PREFIX=$CUDA_QUANTUM_INSTALL_PREFIX/openssl
	mkdir -p $OPENSSL_INSTALL_PREFIX
	export CURL_INSTALL_PREFIX=$CUDA_QUANTUM_INSTALL_PREFIX/curl
	mkdir -p $CURL_INSTALL_PREFIX
	export AWS_INSTALL_PREFIX=$CUDA_QUANTUM_INSTALL_PREFIX/aws
	mkdir -p $AWS_INSTALL_PREFIX

	
	cd $CUDA_QUANTUM_BUILD_PREFIX
	echo $CUDA_QUANTUM_BUILD_PREFIX

	# Install Zlib as it is required for the OpenSSL build.
	# [Zlib] Needed to build LLVM with zlib support (used by linker)
	if [ ! -f "$ZLIB_INSTALL_PREFIX/lib/libz.a" ]; then
	  echo "Installing libz..."
	  wget https://github.com/madler/zlib/releases/download/v1.3/zlib-1.3.tar.gz
	  tar -xzvf zlib-1.3.tar.gz && cd zlib-1.3
	  CC="$CC" CFLAGS="-fPIC" \
	  ./configure --prefix="$ZLIB_INSTALL_PREFIX" --static
	  make CC="$CC" && make install
	  cd contrib/minizip
	  autoreconf --install
	  CC="$CC" CFLAGS="-fPIC" \
	  ./configure --prefix="$ZLIB_INSTALL_PREFIX" --disable-shared
	  make CC="$CC" && make install
	  cd ../../.. && rm -rf zlib-1.3.tar.gz zlib-1.3
	else
	  echo "libz already installed in $ZLIB_INSTALL_PREFIX."
	fi

	cd $CUDA_QUANTUM_BUILD_PREFIX
	# Installing OpenSSL using a modified version of the cuda-quantum script
	# to avoid installing Perl to $HOME.
	# [OpenSSL] Needed for communication with external services
	if [ -n "$OPENSSL_INSTALL_PREFIX" ]; then
	  if [ ! -d "$OPENSSL_INSTALL_PREFIX" ] || [ -z "$(find "$OPENSSL_INSTALL_PREFIX" -name libssl.a)" ]; then
	
	    echo "Installing OpenSSL..."
	
	    wget https://www.openssl.org/source/openssl-3.3.1.tar.gz
	    tar -xf openssl-3.3.1.tar.gz && cd openssl-3.3.1
	    CC="$CC" CFLAGS="-fPIC" CXX="$CXX" CXXFLAGS="-fPIC" AR="${AR:-ar}" \
	    "$PERL_INSTALL_PREFIX/bin/perl" Configure no-shared \
	      --prefix="$OPENSSL_INSTALL_PREFIX" zlib --with-zlib-lib="$ZLIB_INSTALL_PREFIX"
	    make CC="$CC" CXX="$CXX" -j 64 && make install
	    cd .. && rm -rf openssl-3.3.1.tar.gz openssl-3.3.1
	
	  else
	    echo "OpenSSL already installed in $OPENSSL_INSTALL_PREFIX."
	  fi
	fi

	cd $CUDA_QUANTUM_BUILD_PREFIX
	
	## Numpy required for LLVM build
	python -m pip install -v --no-cache-dir "numpy<=1.26.4"
	python -m pip install -v --no-cache-dir  "pybind11"
	python -m pip install -v --no-cache-dir "pytest<=8.3.2"
	python -m pip install -v --no-cache-dir "fastapi<=0.112.2"
	python -m pip install -v --no-cache-dir "uvicorn<=0.30.6"
	python -m pip install -v --no-cache-dir "llvmlite<=0.43.0"
	
        if [[ ! -d cuda-quantum ]]; then
	    git clone -b $CUDA_QUANTUM_VERSION --depth 1 https://github.com/NVIDIA/cuda-quantum
	    sed -Ei '/^export [A-Z_]+_INSTALL_PREFIX=/ s|^export ([A-Z_]+)=(.*)$|export \1=${\1:-\2}|' configure_build.sh
        fi

	cd cuda-quantum/scripts

	# Variables for LLVM build
	export Python3_EXECUTABLE=$(which python)
	export pybind11_DIR="$(python3 -m pybind11 --cmakedir)"

	# Install missing prerequisites. Everything aside from CMake, Ninja, Zlib and OpenSSL.
	LLVM_PROJECTS='clang;flang;lld;mlir;python-bindings;openmp;runtimes'
	bash install_prerequisites.sh

	export PATH=$LLVM_INSTALL_PREFIX/bin:$PATH
	export CPATH=$LLVM_INSTALL_PREFIX/include:$CPATH
	export LIBRARY_PATH=$LLVM_INSTALL_PREFIX/lib:$LIBRARY_PATH
	export LD_LIBRARY_PATH=$LLVM_INSTALL_PREFIX/lib:$LD_LIBRARY_PATH

	#########################
	# build and install nvq++
	#########################

	CUDAQ_WERROR=OFF CUDAQ_PYTHON_SUPPORT=FALSE bash build_cudaq.sh

	# configure clang to use libstdc++ (GCC)
	sed -i '1i --stdlib=libstdc++' $LLVM_INSTALL_PREFIX/bin/clang++.cfg

	MPI_PATH=$MPI_HOME
	cd $CUDAQ_INSTALL_PREFIX/distributed_interfaces
	. activate_custom_mpi.sh


	################################
	# build and install cudaq-python
	################################

	cd $CUDA_QUANTUM_BUILD_PREFIX/cuda-quantum
	rm -rf _skbuild

	python -m pip install --upgrade build

	# build the wheel
	CMAKE_PREFIX_PATH="$(dirname "$(dirname "$PYBIND11_INSTALL_PREFIX")"):$CMAKE_PREFIX_PATH" \
	PATH="$LLVM_INSTALL_PREFIX/bin:$PATH" \
	CPATH="$LLVM_INSTALL_PREFIX/include:$CPATH" \
	LIBRARY_PATH="$LLVM_INSTALL_PREFIX/lib:$LIBRARY_PATH" \
	LD_LIBRARY_PATH="$LLVM_INSTALL_PREFIX/lib:$LD_LIBRARY_PATH" \
	CC="$LLVM_INSTALL_PREFIX/bin/clang" \
	CXX="$LLVM_INSTALL_PREFIX/bin/clang++" \
	FC="$LLVM_INSTALL_PREFIX/bin/flang-new" \
	CXXFLAGS="${CXXFLAGS:-} -Wno-deprecated-declarations" \
	CUDAFLAGS="${CUDAFLAGS:-} -Xcompiler=-Wno-deprecated-declarations -Wno-deprecated-gpu-targets" \
	CMAKE_ARGS="-DCMAKE_COMPILE_WARNING_AS_ERROR=OFF \
	            -DCMAKE_CUDA_FLAGS='-Xcompiler=-Wno-deprecated-declarations -Wno-deprecated-gpu-targets' \
		    -DCMAKE_INTERPROCEDURAL_OPTIMIZATION=OFF \
		    -DLLVM_ENABLE_LTO=Off \
	            -DCMAKE_CXX_FLAGS='-stdlib=libstdc++'" \
	CUDAQ_WERROR=OFF \
	PYTHONPATH="$PYTHONPATH:$PYBIND11_INSTALL_PREFIX" \
	python3 -m build --wheel


	# install the wheel
	PYTHONUSERBASE=$CUDA_QUANTUM_INSTALL_PREFIX python3 -m pip install --user --no-deps dist/cuda_quantum*.whl

	module unload python

	MODULE_TEMP_PATH="$BUILD_PREFIX/$CUDA_QUANTUM_VERSION"
	cp $SETUP_PREFIX/modules/cudaq_module $MODULE_TEMP_PATH
	sed -i "s|CUDAQVERSION|$CUDA_QUANTUM_VERSION|g" "$MODULE_TEMP_PATH"
	sed -i "s|CUDAVERSION|$CUDA_MAJOR_MINOR_VERSION|g" "$MODULE_TEMP_PATH"
	sed -i "s|GCCVERSION|$GCC_VERSION|g" "$MODULE_TEMP_PATH"
	sed -i "s|NVHPCVERSION|$NVHPC_VERSION|g" "$MODULE_TEMP_PATH"
	sed -i "s|CUQUANTUMVERSION|$CUQUANTUM_VERSION|g" "$MODULE_TEMP_PATH"
	sed -i "s|PYTHONVERSION|$PYTHON_VERSION|g" "$MODULE_TEMP_PATH"
	sed -i "s|CUDAQROOT|$CUDAQ_INSTALL_PREFIX|g" "$MODULE_TEMP_PATH"
	mkdir -p $CUDAQ_MODULE_PREFIX
	mv "$MODULE_TEMP_PATH" "$CUDAQ_MODULE_PREFIX/$CUDA_QUANTUM_VERSION.lua"
	
done

