#!/usr/bin/env bash
source settings.sh

PRGENV_TEMPLATE_NAME=${PRGENV_TEMPLATE_NAME:-prgenv_module}
PRGENV_MODULE_NAME=${PRGENV_MODULE_NAME:-nvhpc-gcc-mpi}

TEMPLATE_PATH="${SETUP_PREFIX}/modules/${PRGENV_TEMPLATE_NAME}"
TEMP_MODULE_PATH="${BUILD_PREFIX}/${NVHPC_VERSION}.lua"
INSTALL_DIR="${MODULE_PREFIX}/PrgEnv/${PRGENV_MODULE_NAME}"
INSTALL_PATH="${INSTALL_DIR}/${NVHPC_VERSION}.lua"

module load hpcx-mt-ompi
module load nvhpc/${NVHPC_VERSION}
module load gcc/${GCC_VERSION}

mkdir -p "${BUILD_PREFIX}"
mkdir -p "${INSTALL_DIR}"

cp "${TEMPLATE_PATH}" "${TEMP_MODULE_PATH}"

sed -i.bak "s|NVHPCVERSION|${NVHPC_VERSION}|g" "${TEMP_MODULE_PATH}" && rm -f "${TEMP_MODULE_PATH}.bak"
sed -i.bak "s|GCCVERSION|${GCC_VERSION}|g"     "${TEMP_MODULE_PATH}" && rm -f "${TEMP_MODULE_PATH}.bak"
mv -f "${TEMP_MODULE_PATH}" "${INSTALL_PATH}"

module unload gcc/${GCC_VERSION}
module unload nvhpc/${NVHPC_VERSION}
module unload hpcx-mt-ompi

