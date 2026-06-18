if [ -z ${__PSC_SETTINGS__+x} ]; then # include guard
__PSC_SETTINGS__=1

# EDIT at each rebuild of the software stack
DATE_TAG="2026.08"
SYSTEM="ella"
SETUP_PREFIX=$PWD # folder containing settings.sh ./scripts and ./modules
BUILD_PREFIX=/tmp/$DATE_TAG
MODULE_TEMP_PREFIX=$BUILD_PREFIX/modules

# using project directory for test deployment
if [ -z ${INSTALL_PREFIX+x} ]; then
    INSTALL_PREFIX="/software/ella/software/${DATE_TAG}"
fi

if [ "${INSTALL_PREFIX%$DATE_TAG}" = "${INSTALL_PREFIX}" ]; then
    echo "The path in 'INSTALL_PREFIX' must end with ${DATE_TAG} but its value is ${INSTALL_PREFIX}"
    exit 1
fi

# using project directory for test deployment
if [ -z ${MODULE_PREFIX+x} ]; then
    MODULE_PREFIX="/software/ella/${DATE_TAG}"
fi

if [ "${MODULE_PREFIX%$DATE_TAG}" = "$MODULE_PREFIX}" ]; then
    echo "The path in 'INSTALL_PREFIX' must end with ${DATE_TAG} but its value is ${INSTALL_PREFIX}"
    exit 1
fi

# toolchain used by the nvhpc installs, will also be used to build python and hip
HOST_CC=$(which gcc)
HOST_CXX=$(which g++)
HOST_FC=$(which gfortran)
HOST_GCC_AR=$(which gcc-ar)
HOST_GCC_RANLIB=$(which gcc-ranlib)

# Software versions

AUTOCONF_VERSION=2.72
AUTOMAKE_VERSION=1.17
LIBTOOL_VERSION=2.4.7
PKG_CONFIG_VERSION=0.29.2
BINUTILS_VERSION=2.43.1
MPDECIMAL_VERSION=4.0.0
XZ_VERSION=5.6.2
SQLITE_VERSION=3.46.1
ZLIB_VERSION=1.3
EXPAT_VERSION=2.6.3
LIBFFI_VERSION=3.4.4
BZIP2_VERSION=1.0.8
OPENSSL_VERSION=3.3.1
OPENLDAP_VERSION=2_6_8

GIT_VERSION=2.43.5

GCC_VERSION=13.4.0
NVHPC_VERSION=26.3
NVHPC_OPENMPI_VERSION=3.1.5

CMAKE_VERSIONS=( 3.26.4 )
CMAKE_VERSION=3.26.4

NINJA_VERSION=1.13.1

PYTHON_VERSIONS=( 3.12.11 )
SETUPTOOLS_VERSION=80.9.0
PIP_VERSION=25.2
PYTHON_DEFAULT_VERSION=3.12.11

# cuTENSOR — install both CUDA variants; consumers pin via the _cudaXX suffix.
CUTENSOR_VERSIONS=( "2.6.0"    "2.6.0"    )
CUTENSOR_BUILDS=(   "4_cuda13" "4_cuda12" )

# cuDNN — only the cuda13 variant; PyTorch builds against this. Add a cuda12
# row and the install_cudnn.sh loop will handle it if a consumer needs it.
CUDNN_VERSIONS=( "9.21.1.3" )
CUDNN_BUILDS=(   "cuda13"   )

# Per-consumer pins with _cudaXX suffix.
PYTORCH_CUDNN_VERSION=9.21.1.3_cuda13

CUPY_VERSION=14.0.0
CUPY_GIT_TAG=v14


# Three cuQuantum SDKs coexist, each with an explicit CUDA-major build:
#   25.11.1_cuda13 — qiskit-aer 0.17.2 calls cutensornetContractionOptimize
#                    (removed in cuTensorNet 2.11+). PennyLane-Lightning uses
#                    the same build for uniformity.
#   26.03.1_cuda12 — reserved for cuda-q 0.14+ (cuDensityMat >= 0.4); the AOT
#                    pass-manager crash is unresolved, build preserved as
#                    dev/research scaffolding.
#   25.09.0_cuda12 — cuda-q 0.12's contemporary cuDensityMat 0.2 API. The
#                    mpi_support.cpp in 0.12 expects the old
#                    cudensitymatMpiBarrier(comm, opaque) 2-arg signature
#                    which was dropped in 0.4+.
# There is intentionally no scalar CUQUANTUM_VERSION — every consumer pins.
CUQUANTUM_VERSIONS=(     "25.11.1"   "26.03.1"  "25.09.0"  )
CUQUANTUM_BUILD_NUMBER=( "11_cuda13" "9_cuda12" "7_cuda12" )

# Per-consumer version+CUDA pins (suffix disambiguates parallel installs).
QISKIT_AER_CUQUANTUM_VERSION=25.11.1_cuda13
QISKIT_AER_CUTENSOR_VERSION=2.6.0_cuda13

PENNYLANE_LIGHTNING_CUQUANTUM_VERSION=25.11.1_cuda13
PENNYLANE_LIGHTNING_CUTENSOR_VERSION=2.6.0_cuda13

CUDA_QUANTUM_CUQUANTUM_VERSION=25.09.0_cuda12
CUDA_QUANTUM_CUTENSOR_VERSION=2.6.0_cuda12

CUPY_CUTENSOR_VERSION=2.6.0_cuda13
CUQUANTUM_PYTHON_CUTENSOR_VERSION=2.6.0_cuda13

# CUDA-Q is NOT BUILT in this release. We tested 0.12 / 0.13 / 0.14 / main-HEAD
# against this stack (NVHPC 26.3, CUDA 12.9 / 13.1) and every version crashes
# with `realloc(): invalid pointer` somewhere in the MLIR-backed compile/execute
# path on aarch64. The 2025.10 stack (NVHPC 25.3 / CUDA 12.8) built the same
# cuda-q 0.12.0 successfully, so the regression lives in the NVHPC 26.3
# toolchain (its bundled LLVM / cudart / math_libs vs our user-built LLVM 16).
#
# install_cudaq.sh, modules/cudaq_module, tests/test_cudaq.py are preserved
# intact. install_software_stack.sh and run_tests.sh have the cudaq calls
# commented out. To resume when NVIDIA fixes aarch64 CI (or to retry with a
# parallel NVHPC 25.3 install):
#   1. pick CUDA_QUANTUM_VERSION / _GIT_REF below
#   2. uncomment `bash scripts/install_cudaq.sh` in install_software_stack.sh
#   3. uncomment the CUDA-Q block in run_tests.sh
#
# CUDA_QUANTUM_GIT_REF can be a release tag (0.12.0, 0.14.0, ...) or a branch
# name (main); install_cudaq.sh's sed patches are version-guarded.
CUDA_QUANTUM_VERSION=0.12.0
CUDA_QUANTUM_GIT_REF=0.12.0

# cuQuantum Python wheel — bundles its own shared libs, independent of the C SDK above.
CUQUANTUM_PYTHON_VERSION=25.11.1

MPI4PY_VERSION=4.0.1

QISKIT_AER_VERSION=0.17.2

PENNYLANE_LIGHTNING_VERSION=v0.44.0

PYTORCH_VERSION=2.11.0
# GPU compute capability used by Lightning-GPU / Lightning-Tensor (Ella GH200 = 90)
PENNYLANE_LIGHTNING_CUDA_ARCH=90
# Kokkos arch macro name for Lightning-Kokkos CUDA (see Kokkos CMake Arch_* flags)
PENNYLANE_LIGHTNING_KOKKOS_ARCH=HOPPER90

ROCM_VERSION=7.0 # major.minor
ROCM_FULL_VERSION=7.0.1 # major.minor.patch

SPACK_VERSION=0.23.1

# make directories if they don't exist
mkdir -p $INSTALL_PREFIX
mkdir -p $MODULE_PREFIX
mkdir -p $BUILD_PREFIX/modules

module purge
module load pawsey

export MODULEPATH=$MODULE_PREFIX:$MODULEPATH
# NVIDIA's installer ships per-variant modulefiles (nvhpc-nompi-cuda12,
# nvhpc-hpcx-cuda13, ...). Expose them alongside the system NVHPC (24.5/24.9/25.3)
# so `module avail nvhpc` lists all of them together.
if [ -d "$INSTALL_PREFIX/nvhpc-$NVHPC_VERSION/modulefiles" ]; then
    export MODULEPATH="$INSTALL_PREFIX/nvhpc-$NVHPC_VERSION/modulefiles:$MODULEPATH"
fi

fi # close include guard
