# Strip the auto-loaded 2024.10 stack so the LLVM link step can't pick up
# /software/ella/2024.10/gcc-13.3.0/lib/libstdc++ via ld.so.cache.
module unload pawseyenv 2>/dev/null || true
module unuse /software/ella/2024.10 2>/dev/null || true
unset GCC_PATH LD_SO_CACHE __LMOD_REF_COUNT_LD_SO_CACHE PYTHONPATH PYTHONUSERBASE
for v in LD_LIBRARY_PATH PATH CPATH LIBRARY_PATH PKG_CONFIG_PATH CMAKE_PREFIX_PATH MANPATH; do
    if [ -n "${!v}" ]; then
        export "$v"="$(printf '%s' "${!v}" | tr ':' '\n' | grep -v '/software/ella/2024\.10\|/software/ella/software/2024\.10' | grep -v '^$' | paste -sd:)"
    fi
done

source settings.sh

module load cmake/$CMAKE_VERSION
module load ninja/$NINJA_VERSION
module load nvhpc/$NVHPC_VERSION
module load gcc/$GCC_VERSION 
module load hpcx-mt-ompi
module load cuquantum/$CUDA_QUANTUM_CUQUANTUM_VERSION

export CC=$(which gcc)
export CXX=$(which g++)
export FC=$(which gfortran)

export CUQUANTUM_INSTALL_PREFIX=$CUQUANTUM_ROOT
export CUTENSOR_INSTALL_PREFIX=$CUTENSOR_ROOT
export PERL_INSTALL_PREFIX=$PERL_ROOT

CUDA_MAJOR_MINOR_VERSION=$(nvcc --version | grep -o "release [0-9]\+\.[0-9]\+" | awk '{split($2, a, "."); print a[1] "." a[2]}')
# The versioned cuda/<ver>/ subdir is required; NVHPC's compilers/bin/nvcc wrapper
# makes FindCUDAToolkit resolve to a non-existent cuda/targets/sbsa-linux/ path.
export CUDA_HOME=$NVHPC_ROOT/cuda/$CUDA_MAJOR_MINOR_VERSION
export CUDA_PATH=$NVHPC_ROOT/cuda/$CUDA_MAJOR_MINOR_VERSION
export CUDACXX=$NVHPC_ROOT/cuda/$CUDA_MAJOR_MINOR_VERSION/bin/nvcc
export CUDAToolkit_ROOT=$NVHPC_ROOT/cuda/$CUDA_MAJOR_MINOR_VERSION

ulimit -n 10000   # CUDA-Q build opens thousands of files during LLVM link

for PYTHON_VERSION in "${PYTHON_VERSIONS[@]}"
do
	module load python/$PYTHON_VERSION
	
	CUDA_QUANTUM_BUILD_PREFIX=$BUILD_PREFIX/py-$PYTHON_VERSION-cudaq-${CUDA_QUANTUM_VERSION}
	CUDA_QUANTUM_INSTALL_PREFIX=$INSTALL_PREFIX/py-$PYTHON_VERSION-cudaq-${CUDA_QUANTUM_VERSION}
	CUDAQ_MODULE_PREFIX=$MODULE_PREFIX/py-$PYTHON_VERSION-cudaq

	if [[ -f "$CUDA_QUANTUM_INSTALL_PREFIX/cudaq/bin/nvq++" ]]; then
		echo "CUDA-Q $CUDA_QUANTUM_VERSION for Python $PYTHON_VERSION already installed. Skipping."
		module unload python/$PYTHON_VERSION
		continue
	fi

	mkdir -p $CUDA_QUANTUM_BUILD_PREFIX
	mkdir -p $CUDA_QUANTUM_INSTALL_PREFIX
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

	# libz is needed by both the LLVM linker and the OpenSSL build below.
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
	# OpenSSL, inlined from cuda-quantum's install_prerequisites.sh so Perl
	# doesn't get installed to $HOME.
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
	
	# Build-time Python deps in an isolated PYTHONUSERBASE so they don't
	# overwrite the shared python site-packages used by CuPy / PennyLane /
	# cuQuantum-Python. Runtime deps are pulled in by the wheel install below.
	# pybind11 must stay below 2.13 — newer versions shifted the cmake package
	# layout in a way scikit-build can't find.
	export PYTHONUSERBASE=$CUDA_QUANTUM_INSTALL_PREFIX
	PIP_FLAGS="-v --user --force-reinstall --no-cache-dir"
	python -m pip install $PIP_FLAGS "numpy>=1.24"
	python -m pip install $PIP_FLAGS "scipy>=1.10.1"
	python -m pip install $PIP_FLAGS "pybind11<2.13"
	python -m pip install $PIP_FLAGS "pytest"
	
        if [[ ! -d cuda-quantum ]]; then
	    git clone -b $CUDA_QUANTUM_VERSION --depth 1 https://github.com/NVIDIA/cuda-quantum

	    # Make upstream's *_INSTALL_PREFIX exports conditional so our values survive
	    # `source configure_build.sh`.
	    sed -Ei '/^export [A-Z_]+_INSTALL_PREFIX=/ s|^export ([A-Z_]+)=(.*)$|export \1=${\1:-\2}|' cuda-quantum/scripts/configure_build.sh

	    # aarch64 RHEL's GNUInstallDirs defaults curl to lib64/, but both the skip
	    # check and the main build look for lib/libcurl.a.
	    sed -i 's|-DCMAKE_INSTALL_PREFIX="$CURL_INSTALL_PREFIX"|-DCMAKE_INSTALL_PREFIX="$CURL_INSTALL_PREFIX" -DCMAKE_INSTALL_LIBDIR=lib|' cuda-quantum/scripts/install_prerequisites.sh

	    # CUDAToolkit_INCLUDE_DIRS is a list; upstream's `${VAR}/cccl` only appends
	    # /cccl to the last entry. Use list(TRANSFORM ... APPEND) instead.
	    sed -i '/find_package(CUDAToolkit REQUIRED)/a\
set(_CUDAToolkit_CCCL_INCLUDE_DIRS "${CUDAToolkit_INCLUDE_DIRS}")\
list(TRANSFORM _CUDAToolkit_CCCL_INCLUDE_DIRS APPEND "/cccl")' cuda-quantum/runtime/nvqir/custatevec/CMakeLists.txt
	    sed -i 's|\${CUDAToolkit_INCLUDE_DIRS}/cccl|\${_CUDAToolkit_CCCL_INCLUDE_DIRS}|g' cuda-quantum/runtime/nvqir/custatevec/CMakeLists.txt

	    # install(EXPORT) CheckInterfaceDirs rejects source-tree paths that leak in
	    # transitively from LLVM/MLIR. Clamp to install-interface only.
	    sed -i '/^install(TARGETS \${LIBRARY_NAME} EXPORT cudaq-targets/i\
set_target_properties(${LIBRARY_NAME} PROPERTIES\
    INTERFACE_INCLUDE_DIRECTORIES "$<INSTALL_INTERFACE:include>")\
' cuda-quantum/runtime/cudaq/CMakeLists.txt

        fi

	cd cuda-quantum/scripts

	export Python3_EXECUTABLE=$(which python)
	export pybind11_DIR="$(python3 -m pybind11 --cmakedir)"

	LLVM_PROJECTS='clang;flang;lld;mlir;python-bindings;openmp;runtimes'
	bash install_prerequisites.sh

	export PATH=$LLVM_INSTALL_PREFIX/bin:$PATH
	export CPATH=$LLVM_INSTALL_PREFIX/include:$CPATH
	export LIBRARY_PATH=$LLVM_INSTALL_PREFIX/lib:$LIBRARY_PATH
	export LD_LIBRARY_PATH=$LLVM_INSTALL_PREFIX/lib:$LD_LIBRARY_PATH

	# nvq++
	CUDAQ_WERROR=OFF CUDAQ_PYTHON_SUPPORT=FALSE bash build_cudaq.sh

	# The bundled clang++ defaults to libc++; force libstdc++ to match our gcc toolchain.
	sed -i '1i --stdlib=libstdc++' $LLVM_INSTALL_PREFIX/bin/clang++.cfg

	MPI_PATH=$MPI_HOME
	cd $CUDAQ_INSTALL_PREFIX/distributed_interfaces
	. activate_custom_mpi.sh

	# Python wheel
	cd $CUDA_QUANTUM_BUILD_PREFIX/cuda-quantum
	rm -rf _skbuild

	python -m pip install --upgrade build

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

	PYTHONUSERBASE=$CUDA_QUANTUM_INSTALL_PREFIX python3 -m pip install --user --no-deps dist/cuda_quantum*.whl

	module unload python

	MODULE_TEMP_PATH="$BUILD_PREFIX/$CUDA_QUANTUM_VERSION"
	cp $SETUP_PREFIX/modules/cudaq_module $MODULE_TEMP_PATH
	sed -i "s|CUDAQVERSION|$CUDA_QUANTUM_VERSION|g" "$MODULE_TEMP_PATH"
	sed -i "s|CUDAVERSION|$CUDA_MAJOR_MINOR_VERSION|g" "$MODULE_TEMP_PATH"
	sed -i "s|GCCVERSION|$GCC_VERSION|g" "$MODULE_TEMP_PATH"
	sed -i "s|NVHPCVERSION|$NVHPC_VERSION|g" "$MODULE_TEMP_PATH"
	sed -i "s|CUQUANTUMVERSION|$CUDA_QUANTUM_CUQUANTUM_VERSION|g" "$MODULE_TEMP_PATH"
	sed -i "s|CUDAQPYSITEPACKAGES|$CUDA_QUANTUM_INSTALL_PREFIX/lib/python${PYTHON_VERSION:0:4}/site-packages|g" "$MODULE_TEMP_PATH"
	sed -i "s|PYTHONVERSION|$PYTHON_VERSION|g" "$MODULE_TEMP_PATH"
	sed -i "s|CUDAQROOT|$CUDAQ_INSTALL_PREFIX|g" "$MODULE_TEMP_PATH"
	mkdir -p $CUDAQ_MODULE_PREFIX
	mv "$MODULE_TEMP_PATH" "$CUDAQ_MODULE_PREFIX/$CUDA_QUANTUM_VERSION.lua"
	
done

