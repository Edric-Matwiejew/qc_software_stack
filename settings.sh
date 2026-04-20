if [ -z ${__PSC_SETTINGS__+x} ]; then # include guard
__PSC_SETTINGS__=1

# EDIT at each rebuild of the software stack
DATE_TAG="2026.04"
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

CUTENSOR_VERSIONS=( 2.6.0 )
CUTENSOR_VERSION=2.6.0
CUTENSOR_BUILDS=( "4_cuda13" )

CUPY_VERSION=14.0.0
CUPY_GIT_TAG=v14


# Two cuQuantum SDKs coexist: 25.11.1 for qiskit-aer and PennyLane-Lightning
# (qiskit-aer 0.17.2 calls cutensornetContractionOptimize, removed in 2.11+);
# 26.03.1 for CUDA-Q (needs cuDensityMat >= 0.4). Each consumer pins below;
# there is intentionally no scalar CUQUANTUM_VERSION.
CUQUANTUM_VERSIONS=( "25.11.1" "26.03.1" )
CUQUANTUM_BUILD_NUMBER=( "11_cuda13" "9_cuda13" )

QISKIT_AER_CUQUANTUM_VERSION=25.11.1
CUDA_QUANTUM_CUQUANTUM_VERSION=26.03.1
PENNYLANE_LIGHTNING_CUQUANTUM_VERSION=25.11.1

# CUDA-Q 0.14 is not built in this release — crashes in its new AOT
# Python->MLIR pass manager on aarch64 + CUDA 13. install_cudaq.sh,
# modules/cudaq_module and tests/test_cudaq.py are kept for the next attempt;
# orchestration calls are commented out in install_software_stack.sh and
# run_tests.sh.
CUDA_QUANTUM_VERSION=0.14.0

# cuQuantum Python wheel — bundles its own shared libs, independent of the C SDK above.
CUQUANTUM_PYTHON_VERSION=25.11.1

MPI4PY_VERSION=4.0.1

QISKIT_AER_VERSION=0.17.2

PENNYLANE_LIGHTNING_VERSION=v0.44.0
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

fi # close include guard
