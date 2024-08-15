if [ -z ${__PSC_SETTINGS__+x} ]; then # include guard
__PSC_SETTINGS__=1

# EDIT at each rebuild of the software stack
DATE_TAG="2024.08.01"
SYSTEM="ella"
SETUP_PREFIX=$PWD # folder containing settings.sh ./scripts and ./modules
BUILD_PREFIX=/tmp/$DATE_TAG
MODULE_TEMP_PREFIX=$BUILD_PREFIX/modules

# using project directory for test deployment
if [ -z ${INSTALL_PREFIX+x} ]; then
    INSTALL_PREFIX="/pawsey/software/projects/pawsey0001/software/${DATE_TAG}"
fi

if [ "${INSTALL_PREFIX%$DATE_TAG}" = "${INSTALL_PREFIX}" ]; then
    echo "The path in 'INSTALL_PREFIX' must end with ${DATE_TAG} but its value is ${INSTALL_PREFIX}"
    exit 1
fi

# using project directory for test deployment
if [ -z ${MODULE_PREFIX+x} ]; then
    MODULE_PREFIX="/pawsey/software/projects/pawsey0001/modules/${DATE_TAG}"
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

NVHPC_VERSION=24.7
PYTHON_VERSIONS=( 3.10 3.12 )
PYTHON_DEFAULT_VERSION=3.10

# make directories if they don't exist
mkdir -p $INSTALL_PREFIX
mkdir -p $MODULE_PREFIX
mkdir -p $BUILD_PREFIX/modules

#module use $MODULE_PREFIX

fi # close include guard
