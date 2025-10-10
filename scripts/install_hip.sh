#!/bin/bash

source settings.sh

HIP_INSTALL_PREFIX="$INSTALL_PREFIX/hip-${ROCM_FULL_VERSION}"
HIP_BUILD_PREFIX="$BUILD_PREFIX/hip"

module load gcc/$GCC_VERSION
module load nvhpc/$NVHPC_VERSION
module load cmake/$CMAKE_VERSION

ROCM_BRANCH=rocm-${ROCM_FULL_VERSION}

# C and C++ compilers associated with the NVHPC default toolchain
export CC=$(which gcc)
export CXX=$(which g++)
export FC=$(which gfortran)

export CUDA_PATH=$NVHPC_ROOT/cuda

mkdir -p $HIP_INSTALL_PREFIX
mkdir -p $HIP_BUILD_PREFIX
cd $HIP_BUILD_PREFIX

# The llvm-project repository supplies hipcc and hipconfig
git clone --depth 1 -b "$ROCM_BRANCH" https://github.com/ROCm/llvm-project

cd llvm-project/amd/hipcc

# Build hipcc and hipconfig
# Reference: https://rocm.docs.amd.com/projects/HIPCC/en/latest/build.html
mkdir build
cd build
cmake ..
make -j$(nproc)

cd $HIP_BUILD_PREFIX

# Clone the necessary repositories for CLR and HIP
# Reference: https://rocmdocs.amd.com/projects/HIP/en/latest/install/build.html
git clone -b "$ROCM_BRANCH" https://github.com/ROCm/clr.git
git clone -b "$ROCM_BRANCH" https://github.com/ROCm/hip.git
## Required for NVIDIA platforms only
git clone -b "$ROCM_BRANCH" https://github.com/ROCm/hipother.git

export CLR_DIR="$(readlink -f clr)"
export HIP_DIR="$(readlink -f hip)"
export HIP_OTHER="$(readlink -f hipother)"

cd "$CLR_DIR"
mkdir -p build
cd build
cmake -DHIPCC_BIN_DIR=$HIP_BUILD_PREFIX/llvm-project/amd/hipcc/build \
      -DHIP_COMMON_DIR=$HIP_DIR \
      -DHIP_PLATFORM=nvidia \
      -DCMAKE_INSTALL_PREFIX=$HIP_INSTALL_PREFIX \
      -DCLR_BUILD_HIP=ON \
      -DCLR_BUILD_OCL=OFF \
      -DHIPNV_DIR=$HIP_OTHER/hipnv ..
make -j$(nproc)
make install

export HIP_PLATFORM=nvidia
export HIP_COMPILER=nvcc
export HIP_PATH=$HIP_INSTALL_PREFIX
export PATH=$PATH:$HIP_INSTALL_PREFIX/bin


# Function to clone, build, and install a HIP library with specific cmake options
build_and_install() {
    local repo_url=$1
    shift
    local repo_name=$1
    shift
    local cmake_options=("$@")

    git clone --depth 1 -b "$ROCM_BRANCH" "${repo_url}"
    cd "$repo_name"
    cmake -B build -S . \
        -DCMAKE_INSTALL_PREFIX="$HIP_INSTALL_PREFIX" \
        -DCMAKE_PREFIX_PATH="$NVHPC_ROOT/math_libs/lib64" \
        -DCMAKE_MODULE_PATH=$HIP_INSTALL_PREFIX/lib64/cmake/hip \
        "${cmake_options[@]}"
    cmake --build build
    cd build
    make install
    cd $HIP_BUILD_PREFIX
}

build_and_install https://github.com/ROCm/hipBLAS-common hipBLAS-common

build_and_install https://github.com/ROCm/hipBLAS hipBLAS

build_and_install https://github.com/ROCm/hipSPARSE hipSPARSE -DUSE_CUDA=ON

build_and_install  https://github.com/ROCm/hipSOLVER hipSOLVER -DUSE_CUDA=ON -DHIP_ROOT_DIR=$HIP_INSTALL_PREFIX -DHIP_PLATFORM=nvidia -DCMAKE_CXX_FLAGS="-D__HIP_PLATFORM_NVIDIA__"

build_and_install https://github.com/ROCm/hipRAND hipRAND -DBUILD_WITH_LIB=CUDA

cd $HIP_BUILD_PREFIX/..
rm -rf $HIP_BUILD_PREFIX

# Create the module file

cd "$MODULE_TEMP_PREFIX"
cp "$SETUP_PREFIX/modules/hip_module" "$ROCM_FULL_VERSION"

sed -i "s|ROCMHIPVERSION|$ROCM_FULL_VERSION|g" "$ROCM_FULL_VERSION"
sed -i "s|GCCVERSION|$GCC_VERSION|g" "$ROCM_FULL_VERSION"
sed -i "s|HOSTCOMPILER|$CXX|g" "$ROCM_FULL_VERSION"
sed -i "s|NVHPCVERSION|$NVHPC_VERSION|g" "$ROCM_FULL_VERSION"
sed -i "s|NVHPCCUDAPATH|$NVHPC_ROOT/cuda|g" "$ROCM_FULL_VERSION"
sed -i "s|HOSTFortranCOMPILER|$FC|g" "$ROCM_FULL_VERSION"
sed -i "s|ROCMBASE|$HIP_INSTALL_PREFIX|g" "$ROCM_FULL_VERSION"

mkdir -p "$MODULE_PREFIX/hip"
mv "$ROCM_FULL_VERSION" "$MODULE_PREFIX/hip/$ROCM_FULL_VERSION.lua"
