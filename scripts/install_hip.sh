#!/bin/bash

source settings.sh

ROCM_VERSION=6.1 # major.minor
ROCM_FULL_VERSION=6.1.2 # major.minor.patch
NVHPC_VERSION=24.5

HIP_INSTALL_PREFIX="$INSTALL_PREFIX/hip-${ROCM_FULL_VERSION}"
HIP_BUILD_PREFIX="$BUILD_PREFIX/hip"

module load gcc
module load nvhpc/$NVHPC_VERSION
module load cmake

ROCM_BRANCH=rocm-${ROCM_VERSION}.x

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
# Required for NVIDIA platforms only
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
export HIP_COMPILER=$CXX
export HIP_PATH=$HIP_INSTALL_PREFIX
export PATH=$PATH:$HIP_INSTALL_PREFIX/bin

cd $HIP_BUILD_PREFIX

# Branch naming convention is different for the HIP repo
export ROCM_BRANCH=release/rocm-rel-${ROCM_VERSION}

# Function to clone, build, and install a HIP library with specific cmake options
build_and_install() {
    local repo_name=$1
    shift
    local cmake_options=("$@")

    git clone -b "$ROCM_BRANCH" "https://github.com/ROCmSoftwarePlatform/${repo_name}.git"
    cd "$repo_name"
    cmake -B build -S . \
        -DCMAKE_INSTALL_PREFIX="$HIP_INSTALL_PREFIX" \
        -DCMAKE_PREFIX_PATH="$NVHPC_ROOT/math_libs/lib64" \
        "${cmake_options[@]}"
    cmake --build build
    cd build
    make install
    cd $HIP_BUILD_PREFIX
}

build_and_install "hipBLAS" -DCMAKE_MODULE_PATH=$HIP_INSTALL_PREFIX/lib64/cmake/hip

build_and_install "hipSPARSE" -DUSE_CUDA=ON -DCMAKE_MODULE_PATH=$HIP_INSTALL_PREFIX/lib64/cmake/hip

build_and_install "hipSOLVER" -DUSE_CUDA=ON -DCMAKE_MODULE_PATH=$HIP_INSTALL_PREFIX/lib64/cmake/hip -DHIP_ROOT_DIR=$HIP_INSTALL_PREFIX -DHIP_PLATFORM=nvidia -DCMAKE_CXX_FLAGS="-D__HIP_PLATFORM_NVIDIA__"

build_and_install "hipRAND" -DBUILD_WITH_LIB=CUDA -DCMAKE_MODULE_PATH=$HIP_INSTALL_PREFIX/lib64/cmake/hip

# The hipFORT build process is broken when HIP_PLATFORM=nvidia
# https://github.com/ROCm/hipfort/issues/154
# Need to build for both amd and nvidia platforms.

build_and_install "hipFORT" \
        -DHIPFORT_COMPILER_FLAGS="-fallow-argument-mismatch -ffree-form -cpp -ffree-line-length-none -fmax-errors=5" \
       -DHIPFORT_COMPILER=$FC \
       -DHIPFORT_AR=$GCC_AR \
       -DHIPFORT_RANLIB=$GCC_RANLIB \
       -DHIP_PLATFORM=amd \
       -DHIPFORT_INSTALL_PREFIX=$HIP_INSTALL_PREFIX

cd $HIP_BUILD_PREFIX/..
rm -rf $HIP_BUILD_PREFIX

# Create the module file

cd "$MODULE_TEMP_PREFIX"
cp "$SETUP_PREFIX/modules/hip_module" "$ROCM_FULL_VERSION"

sed -i "s|ROCM_HIP_VERSION|$ROCM_FULL_VERSION|g" "$ROCM_FULL_VERSION"
sed -i "s|HOST_COMPILER|$CXX|g" "$ROCM_FULL_VERSION"
sed -i "s|NVHPC_VERSION|$NVHPC_VERSION|g" "$ROCM_FULL_VERSION"
sed -i "s|NVHPC_CUDA_PATH|$NVHPC_ROOT/cuda|g" "$ROCM_FULL_VERSION"
sed -i "s|HOST_Fortran_COMPILER|$FC|g" "$ROCM_FULL_VERSION"
sed -i "s|ROCM_BASE|$HIP_INSTALL_PREFIX|g" "$ROCM_FULL_VERSION"

mkdir -p "$MODULE_PREFIX/hip"
mv "$ROCM_FULL_VERSION" "$MODULE_PREFIX/hip/$ROCM_FULL_VERSION.lua"
