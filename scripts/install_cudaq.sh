#!/bin/bash

source settings.sh


BUILD_PREFIX=test
mkdir -p $BUILD_PREFIX

module use /opt/nvidia/hpc_sdk/modulefiles

#python -m pip install cmake --user

# install script based on:
# https://nvidia.github.io/cuda-quantum/latest/using/install/data_center_install.html

PYTHON_VERSION=3.10
#version from link given at https://developer.nvidia.com/cutensor-downloads
CUTENSOR_VERSION=2.0.2.5

NVQ_INSTALL_PREFIX=$INSTALL_PREFIX/cudaq-nvhpc-$NVHPC_VERSION-py-$PYTHON_VERSION

mkdir -p $NVQ_INSTALL_PREFIX

module load nvhpc/$NVHPC_VERSION
module load python
module load ninja
module load cmake



export CUDAQ_INSTALL_PREFIX=$NVQ_INSTALL_PREFIX/cudaq
export CUQUANTUM_INSTALL_PREFIX=$NVQ_INSTALL_PREFIX/cuquantum
export CUTENSOR_INSTALL_PREFIX=$NVQ_INSTALL_PREFIX/cutensor
export LLVM_INSTALL_PREFIX=$NVQ_INSTALL_PREFIX/llvm
export BLAS_INSTALL_PREFIX=$NVQ_INSTALL_PREFIX/blas
export ZLIB_INSTALL_PREFIX=$NVQ_INSTALL_PREFIX/zlib
export OPENSSL_INSTALL_PREFIX=$NVQ_INSTALL_PREFIX/openssl
export CURL_INSTALL_PREFIX=$NVQ_INSTALL_PREFIX/curl
export PYBIND11_INSTALL_PREFIX=$NVQ_INSTALL_PREFIX/pybind11 
export NUMPY_INSTALL_PREFIX=$NVQ_INSTALL_PREFIX/numpy
export PYTEST_INSTALL_PREFIX=$NVQ_INSTALL_PREFIX/pytest
export PYBUILD_INSTALL_PREFIX=$NVQ_INSTALL_PREFIX/py-build
export PATCHELF_INSTALL_PREFIX=$NVQ_INSTALL_PREFIX/patchelf
export CMAKE_INSTALL_PREFIX=$NVQ_INSTALL_PREFIX/cmake
export FASTAPI_INSTALL_PREFIX=$NVQ_INSTALL_PREFIX/fastapi

export CUDA_PATH=$NVHPC_ROOT/cuda
export CUDACXX=$CUDA_PATH/bin/nvcc
export CUDA_VERSION=$($CUDACXX --version | grep -o "release [0-9]\+\.[0-9]\+" | awk '{print $2}')

#GCC_INSTALL_PREFIX=/usr
export CXX=$HOST_CXX
export CC=$HOST_CC
export FC=$HOST_FC
export GCC_VERSION=$($CC --version | grep -o "gcc (GCC) [0-9]\+\.[0-9]\+\.[0-9]\+" | awk '{print $3}')

cd $BUILD_PREFIX

#wget https://developer.download.nvidia.com/compute/cutensor/redist/libcutensor/linux-sbsa/libcutensor-linux-sbsa-$CUTENSOR_VERSION-archive.tar.xz
#tar -xvf libcutensor-linux-sbsa-$CUTENSOR_VERSION-archive.tar.xz
#mv libcutensor-linux-sbsa-$CUTENSOR_VERSION-archive $CUTENSOR_INSTALL_PREFIX
ls $CUTENSOR_INSTALL_PREFIX

# See also: https://github.com/NVIDIA/cuda-quantum/issues/452
#wget http://www.netlib.org/blas/blas-3.11.0.tgz
#tar -xzvf blas-3.11.0.tgz
#cd BLAS-3.11.0 && make
#mkdir -p "$BLAS_INSTALL_PREFIX"
#mv blas_LINUX.a "$BLAS_INSTALL_PREFIX/libblas.a"
#cd .. && rm -rf blas-3.11.0.tgz BLAS-3.11.0

#wget https://github.com/madler/zlib/releases/download/v1.3/zlib-1.3.tar.gz
#tar -xzvf zlib-1.3.tar.gz && cd zlib-1.3
#CFLAGS="-fPIC" CXXFLAGS="-fPIC" \
#./configure --prefix="$ZLIB_INSTALL_PREFIX" --static
#make && make install
#cd contrib/minizip
#autoreconf --install
#CFLAGS="-fPIC" CXXFLAGS="-fPIC" \
#./configure --prefix="$ZLIB_INSTALL_PREFIX" --disable-shared
#make && make install

# Not all perl installations include all necessary modules.
# To facilitate a consistent build across platforms and to minimize dependencies,
# we just use our own perl version for the OpenSSL build.
#wget https://www.cpan.org/src/5.0/perl-5.38.2.tar.gz
#tar -xzf perl-5.38.2.tar.gz && cd perl-5.38.2
#./Configure -des -Dcc="$CC" -Dprefix=$NVQ_INSTALL_PREFIX/perl
#make -j4 && make install
#cd .. && rm -rf perl-5.38.2.tar.gz perl-5.38.2
# Additional perl modules can be installed with cpan, e.g.
# PERL_MM_USE_DEFAULT=1 ~/.perl5/bin/cpan App::cpanminus

#wget https://www.openssl.org/source/openssl-3.3.1.tar.gz
#tar -xf openssl-3.3.1.tar.gz && cd openssl-3.3.1
#CFLAGS="-fPIC" CXXFLAGS="-fPIC" \
#~/.perl5/bin/perl Configure no-shared no-zlib --prefix="$OPENSSL_INSTALL_PREFIX"
#make -j4 && make install

#rm -rf cuda-quantum
#git clone --branch 0.7.1 https://github.com/NVIDIA/cuda-quantum

cd cuda-quantum

#PYTHONUSERBASE=$CUQUANTUM_INSTALL_PREFIX python -m pip install -v --no-cache-dir --user --force-reinstall cuquantum
#PYTHONUSERBASE=$NUMPY_INSTALL_PREFIX python -m pip install -v numpy==2.0.0 --user --force-reinstall
#PYTHONUSERBASE=$PYBIND11_INSTALL_PREFIX python -m pip install -v pybind11==2.13.1 --user --force-reinstall
#PYTHONUSERBASE=$PYTEST_INSTALL_PREFIX python -m pip install -v pytest==8.2.2 --user --force-reinstall
#PYTHONUSERBASE=$PYBUILD_INSTALL_PREFIX python3 -m pip install -v build==1.2.1 --user --force-reinstall
#PYTHONUSERBASE=$PATCHELF_INSTALL_PREFIX python3 -m pip install -v patchelf==0.17.2.1 --user --force-reinstall
#PYTHONUSERBASE=$FASTAPI_INSTALL_PREFIX python3 -m pip install -v llvmlite==0.43.0 fastapi==0.111.1 scikit-build-core==0.7.1 --user --force-reinstall
export PYTHONPATH=$NUMPY_INSTALL_PREFIX/lib/python3.10/site-packages:$PYBIND11_INSTALL_PREFIX/lib/python3.10/site-packages:$CUQUANTUM_INSTALL_PREFIX/lib/python3.10/site-packages:$PYTEST_INSTALL_PREFIX/lib/python3.10/site-packages:$PYBUILD_INSTALL_PREFIX/lib/python3.10/site-packages:$PATCHELF_INSTALL_PREFIX/lib/python3.10/site-packages:$FASTAPI_INSTALL_PREFIX/lib/python3.10/site-packages:$PYTHONPATH
export PATH=$PATH:$NUMPY_INSTALL_PREFIX/bin:$PYBUILD_INSTALL_PREFIX/bin:$PYTEST_INSTALL_PREFIX/bin:$FASTAPI_INSTALL_PREFIX/bin:$PATCHELF_INSTALL_PREFIX/bin
#source scripts/build_llvm.sh -v
#
##LLVM_PROJECTS='clang;lld;mlir' \
ulimit -n 2048
#export CUDAQ_WERROR=false 
#export CUDAQ_PYTHON_SUPPORT=ON
#export CUDAHOSTCXX="$CXX" 
#source scripts/build_cudaq.sh -v
#python -m numpy
#rm -rf build
#CMAKE_VERBOSE_MAKEFILE=ON \
#bash scripts/install_prerequisites.sh && \
#LDFLAGS='-fPIC' \
#CUDAHOSTCXX="$CXX" \
#python -m build --wheel
CUDAQ_WHEEL="$(find . -name 'cuda_quantum*.whl')" && \
MANYLINUX_PLATFORM="$(echo ${CUDAQ_WHEEL} | grep -o '[a-z]*linux_[^\.]*' | sed -re 's/^linux_/manylinux_2_28_/')" && \
LD_LIBRARY_PATH="${LD_LIBRARY_PATH}:$(pwd)/_skbuild/lib" \
python3 -m auditwheel -v repair ${CUDAQ_WHEEL} \
    --plat ${MANYLINUX_PLATFORM} \
    --exclude libcublas.so.11 \
    --exclude libcublasLt.so.11 \
    --exclude libcusolver.so.11 \
    --exclude libcutensor.so.2 \
    --exclude libcutensornet.so.2 \
    --exclude libcustatevec.so.1 \
    --exclude libcudart.so.11.0
