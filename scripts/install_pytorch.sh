#!/bin/bash
#
# PyTorch from source against NVHPC 26.3 / CUDA 13.1 on GH200 (Hopper cc 9.0).
#
# Key choices:
#   - NCCL from NVHPC's comm_libs (USE_SYSTEM_NCCL=1) so torch.distributed
#     aligns with the HPC-X MPI stack the rest of the system uses.
#   - cuDNN installed up-front by scripts/install_cudnn.sh (inlined here as
#     PyTorch is currently the only consumer); loaded via the cudnn module
#     so CUDNN_INCLUDE_DIR / CUDNN_LIB_DIR are on env for PyTorch's CMake.
#   - MKL / MKLDNN / ROCm off; BLAS auto-detected by CMake. Tests off.
#   - Build-time cmake>=3.27 is pulled in via pip (our stack's cmake/3.26.4
#     is below PyTorch 2.11's floor).
#   - torch.distributed with MPI via hpcx-mt-ompi.

source settings.sh

# cuDNN dependency — standalone install_cudnn.sh is idempotent, so a re-run
# of install_pytorch.sh is cheap. Run in a subshell to keep its `module load`
# side-effects out of our env.
bash "$SETUP_PREFIX/scripts/install_cudnn.sh"

module load gcc/$GCC_VERSION
module load ninja/$NINJA_VERSION
module load hpcx-mt-ompi
module load nvhpc/$NVHPC_VERSION
module load cudnn/$PYTORCH_CUDNN_VERSION

# Pin explicitly to cuda/13.1 subdir. NVHPC multi-CUDA's default symlink
# already points here, but being explicit keeps the build deterministic.
CUDA_MAJOR_MINOR_VERSION=13.1
export CUDA_HOME=$NVHPC_ROOT/cuda/$CUDA_MAJOR_MINOR_VERSION
export CUDA_PATH=$CUDA_HOME
export CUDACXX=$CUDA_HOME/bin/nvcc
export CUDAToolkit_ROOT=$CUDA_HOME
export PATH=$CUDA_HOME/bin:$PATH
export LD_LIBRARY_PATH=$CUDA_HOME/lib64:$NVHPC_ROOT/math_libs/$CUDA_MAJOR_MINOR_VERSION/lib64:$LD_LIBRARY_PATH

# cuFile (GPUDirect Storage). NVHPC 26.3 aarch64 doesn't ship libcufile, but
# PyTorch 2.11's FindCUDAToolkit requires CUDA::cuFile as an IMPORTED target.
# Fetch the NVIDIA redist tarball into a standalone prefix, then symlink its
# lib/ and include/ files into the NVHPC cuda/13.1 targets tree so
# FindCUDAToolkit's standard probe picks them up. Idempotent: re-runs no-op.
CUFILE_VERSION=1.17.1.22
CUFILE_ARCHIVE=libcufile-linux-sbsa-${CUFILE_VERSION}-archive
CUFILE_INSTALL_PREFIX=$INSTALL_PREFIX/cufile-${CUFILE_VERSION}_cuda13

if [ ! -f "$CUFILE_INSTALL_PREFIX/lib/libcufile.so" ]; then
    echo "Installing libcufile ${CUFILE_VERSION}..."
    cd $BUILD_PREFIX
    rm -rf ${CUFILE_ARCHIVE} ${CUFILE_ARCHIVE}.tar.xz
    wget https://developer.download.nvidia.com/compute/cuda/redist/libcufile/linux-sbsa/${CUFILE_ARCHIVE}.tar.xz
    tar -xf ${CUFILE_ARCHIVE}.tar.xz
    mkdir -p $CUFILE_INSTALL_PREFIX
    mv ${CUFILE_ARCHIVE}/* $CUFILE_INSTALL_PREFIX/.
    rm -rf ${CUFILE_ARCHIVE} ${CUFILE_ARCHIVE}.tar.xz
else
    echo "libcufile ${CUFILE_VERSION} already staged at ${CUFILE_INSTALL_PREFIX}"
fi

# Stitch libcufile into the cuda/13.1 targets tree so FindCUDAToolkit sees it.
CUFILE_TARGET_LIBDIR=$CUDA_HOME/targets/sbsa-linux/lib
CUFILE_TARGET_INCDIR=$CUDA_HOME/targets/sbsa-linux/include
for f in "$CUFILE_INSTALL_PREFIX"/lib/libcufile*; do
    [ -e "$f" ] && ln -sfn "$f" "$CUFILE_TARGET_LIBDIR/$(basename "$f")"
done
for f in "$CUFILE_INSTALL_PREFIX"/include/cufile*; do
    [ -e "$f" ] && ln -sfn "$f" "$CUFILE_TARGET_INCDIR/$(basename "$f")"
done

# System NCCL (libnccl.so.2.29 from NVHPC).
export USE_SYSTEM_NCCL=1
export NCCL_ROOT=$NVHPC_ROOT/comm_libs/nccl
export NCCL_INCLUDE_DIR=$NCCL_ROOT/include
export NCCL_LIB_DIR=$NCCL_ROOT/lib
export NCCL_LIBRARY=$NCCL_ROOT/lib/libnccl.so

# GH200 = Hopper cc 9.0.
export TORCH_CUDA_ARCH_LIST="9.0"

export USE_CUDA=1
export USE_CUDNN=1
# CUDNN_ROOT / CUDNN_INCLUDE_DIR / CUDNN_LIB_DIR come from the cudnn module;
# export the library path explicitly since PyTorch's FindCUDNN also looks there.
export CUDNN_LIBRARY=$CUDNN_LIB_DIR/libcudnn.so
export USE_NCCL=1
export USE_DISTRIBUTED=1
export USE_MPI=1
export USE_MKL=0
export USE_MKLDNN=0
export USE_ROCM=0
export BUILD_TEST=0
export USE_NUMPY=1
# cuFile (GPUDirect Storage) is installed inline below; FindCUDAToolkit will
# pick it up from the cuda/13.1 tree after the symlink step.
export USE_CUFILE=1
export CMAKE_BUILD_TYPE=Release

export CC=$(which gcc)
export CXX=$(which g++)
export FC=$(which gfortran)

# MAX_JOBS caps the parallel compile count; PyTorch's build is RAM-heavy
# (NVCC + LLVM per TU) so 64 matches install.slurm's cpus-per-task and
# typically leaves enough memory headroom on a 1-node GH200 box.
export MAX_JOBS=${MAX_JOBS:-64}

for PYTHON_VERSION in "${PYTHON_VERSIONS[@]}"
do
    module load python/$PYTHON_VERSION

    PYTORCH_INSTALL_PREFIX="$INSTALL_PREFIX/py-$PYTHON_VERSION-pytorch-$PYTORCH_VERSION"
    PYTORCH_MODULE_PREFIX="$MODULE_PREFIX/py-$PYTHON_VERSION-pytorch"
    PY_MM=${PYTHON_VERSION:0:4}
    SITE_PACKAGES="$PYTORCH_INSTALL_PREFIX/lib/python${PY_MM}/site-packages"

    if [[ -d "$SITE_PACKAGES/torch" ]]; then
        echo "PyTorch $PYTORCH_VERSION for Python $PYTHON_VERSION already installed. Skipping."
        module unload python/$PYTHON_VERSION
        continue
    fi

    rm -rf "$PYTORCH_INSTALL_PREFIX"
    mkdir -p "$SITE_PACKAGES"

    # Isolate per-version Python env. Build + runtime deps land under
    # PYTORCH_INSTALL_PREFIX via --user + PYTHONUSERBASE.
    export PYTHONUSERBASE="$PYTORCH_INSTALL_PREFIX"
    export PATH="$PYTORCH_INSTALL_PREFIX/bin:$PATH"
    export PYTHONPATH="$SITE_PACKAGES:$PYTHONPATH"

    # Build-time Python deps (PyTorch 2.11 pyproject.toml [build-system]).
    # We pre-install these so --no-build-isolation can use them, avoiding
    # pip's throw-away venv (which would need network bandwidth for every
    # rebuild and makes caching pointless).
    python -m pip install --user --upgrade pip wheel
    python -m pip install --user \
        "setuptools>=70.1.0,<82" "cmake>=3.27" "ninja" "numpy" "packaging" \
        "pyyaml" "requests" "six" "typing_extensions>=4.15.0"

    # Runtime deps (from requirements.txt minus dev/test extras).
    python -m pip install --user \
        "filelock" "sympy>=1.13.3" "networkx>=2.5.1" "jinja2" "fsspec>=0.8.5" \
        "optree>=0.13.0"

    cd $BUILD_PREFIX
    PYTORCH_SRC=$BUILD_PREFIX/pytorch-$PYTHON_VERSION-$PYTORCH_VERSION
    rm -rf "$PYTORCH_SRC"
    # PyTorch vendors ~50 submodules (pybind11, sleef, eigen, onnx, ...).
    # --shallow-submodules keeps total clone size manageable (~1.5 GB).
    git clone --depth 1 --recurse-submodules --shallow-submodules \
        -b "v$PYTORCH_VERSION" https://github.com/pytorch/pytorch "$PYTORCH_SRC"
    cd "$PYTORCH_SRC"

    # Build the wheel. --no-build-isolation = use our pre-installed deps.
    PYTORCH_BUILD_VERSION=$PYTORCH_VERSION PYTORCH_BUILD_NUMBER=1 \
        python setup.py bdist_wheel

    python -m pip install --user --no-deps dist/torch-*.whl

    cd $BUILD_PREFIX
    rm -rf "$PYTORCH_SRC"

    MODULE_TEMP_PATH="$BUILD_PREFIX/$PYTORCH_VERSION.lua"
    cp $SETUP_PREFIX/modules/pytorch_module "$MODULE_TEMP_PATH"
    sed -i "s|PYTORCHVERSION|$PYTORCH_VERSION|g"                  "$MODULE_TEMP_PATH"
    sed -i "s|GCCVERSION|$GCC_VERSION|g"                          "$MODULE_TEMP_PATH"
    sed -i "s|CUDAVERSION|$CUDA_MAJOR_MINOR_VERSION|g"            "$MODULE_TEMP_PATH"
    sed -i "s|NVHPCVERSION|$NVHPC_VERSION|g"                      "$MODULE_TEMP_PATH"
    sed -i "s|CUDNNVERSION|$PYTORCH_CUDNN_VERSION|g"              "$MODULE_TEMP_PATH"
    sed -i "s|PYTORCHROOT|$PYTORCH_INSTALL_PREFIX|g"              "$MODULE_TEMP_PATH"
    sed -i "s|PYTHONVERSION_MAJOR_MINOR|$PY_MM|g"                 "$MODULE_TEMP_PATH"
    sed -i "s|PYTHONVERSION|$PYTHON_VERSION|g"                    "$MODULE_TEMP_PATH"
    mkdir -p "$PYTORCH_MODULE_PREFIX"
    mv "$MODULE_TEMP_PATH" "$PYTORCH_MODULE_PREFIX/${PYTORCH_VERSION}.lua"

    unset PYTHONUSERBASE
    module unload python/$PYTHON_VERSION
done

module unload cudnn/$PYTORCH_CUDNN_VERSION
module unload nvhpc/$NVHPC_VERSION
module unload hpcx-mt-ompi
module unload ninja/$NINJA_VERSION
module unload gcc/$GCC_VERSION
