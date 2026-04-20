#!/bin/bash
#
# Builds the PennyLane-Lightning plugin family. Variants per Python version:
#   kokkos-omp    OpenMP host
#   gpu           Lightning-GPU (cuStateVec)
#   gpu-mpi       Lightning-GPU + MPI (multi-GPU state-vector)
#   tensor        Lightning-Tensor (cuTensorNet)

source settings.sh

module load gcc/$GCC_VERSION
module load cmake/$CMAKE_VERSION
module load ninja/$NINJA_VERSION
module load hpcx-mt-ompi
module load nvhpc/$NVHPC_VERSION
module load cutensor/$CUTENSOR_VERSION
module load cuquantum/$PENNYLANE_LIGHTNING_CUQUANTUM_VERSION

CUDA_MAJOR_VERSION=$(nvcc --version | grep -o "release [0-9]\+\.[0-9]\+" | awk '{split($2, a, "."); print a[1]}')

export CC=$(which gcc)
export CXX=$(which g++)
export FC=$(which gfortran)
export CUDACXX=$(which nvcc)
export CUDA_PATH=$NVHPC_ROOT/cuda
export CUQUANTUM_SDK=$CUQUANTUM_ROOT
export PL_CUDA_VERSION=$CUDA_MAJOR_VERSION

PL_CUDA_ARCH=${PENNYLANE_LIGHTNING_CUDA_ARCH:-90}
PL_KOKKOS_ARCH=${PENNYLANE_LIGHTNING_KOKKOS_ARCH:-HOPPER90}

# variant_id | PL_BACKEND | variant CMAKE_ARGS | needs mpi4py (1/0)
# kokkos-cuda / kokkos-mpi are intentionally absent: PL v0.44 pulls Kokkos 5.1,
# which doesn't compile against CUDA 13 (cudaGraphAddKernelNode signature change).
VARIANTS=(
    "kokkos-omp|lightning_kokkos|-DKokkos_ENABLE_OPENMP=ON -DCMAKE_CXX_STANDARD=20|0"
    "gpu|lightning_gpu|-DCMAKE_CUDA_ARCHITECTURES=${PL_CUDA_ARCH}|0"
    "gpu-mpi|lightning_gpu|-DENABLE_MPI=ON -DCMAKE_CUDA_ARCHITECTURES=${PL_CUDA_ARCH}|1"
    "tensor|lightning_tensor|-DCMAKE_CUDA_ARCHITECTURES=${PL_CUDA_ARCH}|0"
)

for PYTHON_VERSION in "${PYTHON_VERSIONS[@]}"
do
    PY_MM=${PYTHON_VERSION:0:4}

    # PennyLane-Lightning v0.44 requires Python >= 3.11.
    PY_MINOR=${PY_MM#*.}
    if [[ "$PY_MINOR" -lt 11 ]]; then
        echo "Skipping PennyLane Lightning for Python ${PYTHON_VERSION} (v${PENNYLANE_LIGHTNING_VERSION#v} requires >=3.11)."
        continue
    fi

    module load python/$PYTHON_VERSION

    # Snapshot PATH/PYTHONPATH after python is loaded so each variant can restore it.
    _SAVED_PATH="$PATH"
    _SAVED_PYTHONPATH="$PYTHONPATH"

    for VARIANT in "${VARIANTS[@]}"
    do
        IFS='|' read -r VARIANT_ID PL_BACKEND VARIANT_CMAKE_ARGS NEEDS_MPI <<< "$VARIANT"

        PL_INSTALL_PREFIX="$INSTALL_PREFIX/py-$PYTHON_VERSION-pennylane-lightning-${VARIANT_ID}-${PENNYLANE_LIGHTNING_VERSION}"
        PL_MODULE_PREFIX="$MODULE_PREFIX/py-$PYTHON_VERSION-pennylane-lightning-${VARIANT_ID}"
        SITE_PACKAGES="$PL_INSTALL_PREFIX/lib/python${PY_MM}/site-packages"

        # Backend directory inside pennylane_lightning/ — acts as the "already installed" sentinel.
        case "$PL_BACKEND" in
            lightning_kokkos) BACKEND_DIR=lightning_kokkos ;;
            lightning_gpu)    BACKEND_DIR=lightning_gpu ;;
            lightning_tensor) BACKEND_DIR=lightning_tensor ;;
        esac

        if [[ -d "$SITE_PACKAGES/pennylane_lightning/$BACKEND_DIR" ]]; then
            echo "PennyLane Lightning ${VARIANT_ID} ${PENNYLANE_LIGHTNING_VERSION} for Python ${PYTHON_VERSION} already installed. Skipping."
            continue
        fi

        echo "=== Building PennyLane Lightning ${VARIANT_ID} ${PENNYLANE_LIGHTNING_VERSION} for Python ${PYTHON_VERSION} ==="

        rm -rf "$PL_INSTALL_PREFIX"
        mkdir -p "$PL_INSTALL_PREFIX" "$PL_MODULE_PREFIX"

        if [[ "$NEEDS_MPI" == "1" ]]; then
            module load py-$PYTHON_VERSION-mpi4py/$MPI4PY_VERSION
        fi

        export PYTHONUSERBASE="$PL_INSTALL_PREFIX"
        export PATH="$PL_INSTALL_PREFIX/bin:$_SAVED_PATH"
        export PYTHONPATH="$SITE_PACKAGES:$_SAVED_PYTHONPATH"

        # configure_pyproject_toml.py rewrites pyproject.toml per backend,
        # so each variant needs a fresh source tree.
        VARIANT_BUILD_DIR="$BUILD_PREFIX/pennylane-lightning-$PYTHON_VERSION-$VARIANT_ID"
        rm -rf "$VARIANT_BUILD_DIR"
        git clone --depth 1 --branch="$PENNYLANE_LIGHTNING_VERSION" \
            https://github.com/PennyLaneAI/pennylane-lightning "$VARIANT_BUILD_DIR"
        cd "$VARIANT_BUILD_DIR"

        python -m pip install --user --upgrade pip setuptools wheel
        python -m pip install --user --upgrade \
            "cmake" "ninja" "pybind11<2.13" "scikit-build" "tomli" "tomlkit"
        # pennylane / scipy-openblas32 pulled in here because the --no-deps
        # wheel install below skips PL's NVIDIA runtime wheels.
        python -m pip install --user --upgrade "pennylane>=0.44" "scipy-openblas32>=0.3.26" "numpy"

        # Every backend depends on the pennylane_lightning core package, so install
        # lightning_qubit (Python-only) first, then the target backend.
        PL_BACKEND=lightning_qubit python scripts/configure_pyproject_toml.py
        SKIP_COMPILATION=True python -m pip install --user --no-deps --force-reinstall -v .

        PL_BACKEND="$PL_BACKEND" python scripts/configure_pyproject_toml.py
        CMAKE_ARGS="$VARIANT_CMAKE_ARGS" \
            python -m pip install --user --no-deps --force-reinstall -vv .

        cd "$BUILD_PREFIX"
        rm -rf "$VARIANT_BUILD_DIR"

        MODULE_TEMP_PATH="$BUILD_PREFIX/${VARIANT_ID}-${PENNYLANE_LIGHTNING_VERSION}.lua"
        cp "$SETUP_PREFIX/modules/pennylane_lightning_module" "$MODULE_TEMP_PATH"
        sed -i "s|PLVARIANT|$VARIANT_ID|g"                       "$MODULE_TEMP_PATH"
        sed -i "s|PLVERSION|$PENNYLANE_LIGHTNING_VERSION|g"      "$MODULE_TEMP_PATH"
        sed -i "s|GCCVERSION|$GCC_VERSION|g"                     "$MODULE_TEMP_PATH"
        sed -i "s|CUDAVERSION|$CUDA_MAJOR_VERSION|g"             "$MODULE_TEMP_PATH"
        sed -i "s|NVHPCVERSION|$NVHPC_VERSION|g"                 "$MODULE_TEMP_PATH"
        sed -i "s|CUQUANTUMVERSION|$PENNYLANE_LIGHTNING_CUQUANTUM_VERSION|g"  "$MODULE_TEMP_PATH"
        sed -i "s|CUTENSORVERSION|$CUTENSOR_VERSION|g"           "$MODULE_TEMP_PATH"
        sed -i "s|PYTHONVERSION_MAJOR_MINOR|$PY_MM|g"            "$MODULE_TEMP_PATH"
        sed -i "s|PYTHONVERSION|$PYTHON_VERSION|g"               "$MODULE_TEMP_PATH"
        sed -i "s|PLROOT|$PL_INSTALL_PREFIX|g"                   "$MODULE_TEMP_PATH"
        mv "$MODULE_TEMP_PATH" "$PL_MODULE_PREFIX/${PENNYLANE_LIGHTNING_VERSION}.lua"

        # Restore env and unload per-variant modules.
        unset PYTHONUSERBASE
        export PATH="$_SAVED_PATH"
        export PYTHONPATH="$_SAVED_PYTHONPATH"

        if [[ "$NEEDS_MPI" == "1" ]]; then
            module unload py-$PYTHON_VERSION-mpi4py/$MPI4PY_VERSION
        fi
    done

    module unload python/$PYTHON_VERSION
done

module unload cuquantum/$PENNYLANE_LIGHTNING_CUQUANTUM_VERSION
module unload cutensor/$CUTENSOR_VERSION
module unload nvhpc/$NVHPC_VERSION
module unload hpcx-mt-ompi
module unload ninja/$NINJA_VERSION
module unload cmake/$CMAKE_VERSION
module unload gcc/$GCC_VERSION
