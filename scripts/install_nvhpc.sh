#!/bin/bash

source settings.sh

NVHPC_ARCH=Linux_aarch64
NVHPC_YEAR=$(echo $NVHPC_VERSION | cut -d. -f1)
NVHPC_MINOR=$(echo $NVHPC_VERSION | cut -d. -f2)
NVHPC_YEAR_FULL="20${NVHPC_YEAR}"
NVHPC_TAG="${NVHPC_YEAR}${NVHPC_MINOR}"

NVHPC_INSTALL_PREFIX=$INSTALL_PREFIX/nvhpc-${NVHPC_VERSION}
NVHPC_MODULE_DIR=$MODULE_PREFIX/nvhpc
NVHPC_CUDA_VERSION=13.1
NVHPC_ARCHIVE=nvhpc_${NVHPC_YEAR_FULL}_${NVHPC_TAG}_${NVHPC_ARCH}_cuda_${NVHPC_CUDA_VERSION}

if [[ -d "$NVHPC_INSTALL_PREFIX/${NVHPC_ARCH}/${NVHPC_VERSION}" ]]; then
    echo "NVHPC ${NVHPC_VERSION} already installed at ${NVHPC_INSTALL_PREFIX}. Skipping."
else
    echo "Installing NVHPC ${NVHPC_VERSION}..."
    cd $BUILD_PREFIX

    NVHPC_URL="https://developer.download.nvidia.com/hpc-sdk/${NVHPC_VERSION}/${NVHPC_ARCHIVE}.tar.gz"

    # Get file size for splitting
    FILESIZE=$(curl -sI "$NVHPC_URL" | grep -i content-length | awk '{print $2}' | tr -d '\r')
    NTHREADS=8
    CHUNKSIZE=$(( FILESIZE / NTHREADS ))

    echo "Downloading ${NVHPC_ARCHIVE}.tar.gz (${FILESIZE} bytes) with ${NTHREADS} threads..."

    # Download chunks in parallel
    PIDS=()
    for i in $(seq 0 $(( NTHREADS - 1 ))); do
        START=$(( i * CHUNKSIZE ))
        if [[ $i -eq $(( NTHREADS - 1 )) ]]; then
            END=$FILESIZE
        else
            END=$(( START + CHUNKSIZE - 1 ))
        fi
        curl -s -L --range ${START}-${END} -o "part_${i}" "$NVHPC_URL" &
        PIDS+=($!)
    done

    # Wait for all chunks
    for PID in "${PIDS[@]}"; do
        wait $PID
    done

    # Merge chunks
    cat $(seq 0 $(( NTHREADS - 1 )) | sed 's/^/part_/') > ${NVHPC_ARCHIVE}.tar.gz
    rm -f part_*

    tar -xzf ${NVHPC_ARCHIVE}.tar.gz

    # Auto-answer installer prompts:
    # 1. Enter to continue past header
    # 2. "1" for single-system install
    # 3. Custom installation directory
    printf "\n1\n${NVHPC_INSTALL_PREFIX}\n" | \
        ${NVHPC_ARCHIVE}/install

    cd $BUILD_PREFIX
    rm -rf ${NVHPC_ARCHIVE}.tar.gz ${NVHPC_ARCHIVE}
fi

# Derive CUDA version from the installed nvcc
NVCC_BIN=$NVHPC_INSTALL_PREFIX/${NVHPC_ARCH}/${NVHPC_VERSION}/compilers/bin/nvcc
CUDA_MAJOR_VERSION=$($NVCC_BIN --version | grep -o "release [0-9]\+\.[0-9]\+" | awk '{split($2, a, "."); print a[1]}')

# Create Lua module file that mirrors the system nvhpc module structure
mkdir -p $NVHPC_MODULE_DIR
MODULE_PATH=$NVHPC_MODULE_DIR/${NVHPC_VERSION}.lua

cat > $MODULE_PATH << EOF
-- -*- lua -*-
help([[
NVIDIA HPC SDK ${NVHPC_VERSION} with CUDA ${CUDA_MAJOR_VERSION}
Installed at ${NVHPC_INSTALL_PREFIX}
]])

whatis("Name: NVHPC ${NVHPC_VERSION}")
whatis("CUDA Version: ${CUDA_MAJOR_VERSION}")

conflict("nvhpc")

local nvhome    = "${NVHPC_INSTALL_PREFIX}"
local target    = "${NVHPC_ARCH}"
local version   = "${NVHPC_VERSION}"

local nvroot    = pathJoin(nvhome, target, version)
local nvcudadir = pathJoin(nvroot, "cuda")
local nvcompdir = pathJoin(nvroot, "compilers")
local nvmathdir = pathJoin(nvroot, "math_libs")
local nvcommdir = pathJoin(nvroot, "comm_libs")

setenv("NVHPC",      nvhome)
setenv("NVHPC_ROOT", nvroot)
setenv("CC",         pathJoin(nvcompdir, "bin/nvc"))
setenv("CXX",        pathJoin(nvcompdir, "bin/nvc++"))
setenv("FC",         pathJoin(nvcompdir, "bin/nvfortran"))
setenv("F90",        pathJoin(nvcompdir, "bin/nvfortran"))
setenv("F77",        pathJoin(nvcompdir, "bin/nvfortran"))

prepend_path("PATH", pathJoin(nvcudadir, "bin"))
prepend_path("PATH", pathJoin(nvcompdir, "bin"))
prepend_path("PATH", pathJoin(nvcompdir, "extras/qd/bin"))

prepend_path("LD_LIBRARY_PATH", pathJoin(nvcudadir, "lib64"))
prepend_path("LD_LIBRARY_PATH", pathJoin(nvcompdir, "lib"))
prepend_path("LD_LIBRARY_PATH", pathJoin(nvcompdir, "extras/qd/lib"))
prepend_path("LD_LIBRARY_PATH", pathJoin(nvmathdir, "lib64"))
prepend_path("LD_LIBRARY_PATH", pathJoin(nvcommdir, "nccl/lib"))
prepend_path("LD_LIBRARY_PATH", pathJoin(nvcommdir, "nvshmem/lib"))

prepend_path("CPATH", pathJoin(nvmathdir, "include"))
prepend_path("CPATH", pathJoin(nvcommdir, "nccl/include"))
prepend_path("CPATH", pathJoin(nvcommdir, "nvshmem/include"))
prepend_path("CPATH", pathJoin(nvcompdir, "extras/qd/include/qd"))

prepend_path("LIBRARY_PATH", pathJoin(nvcudadir, "lib64"))
prepend_path("LIBRARY_PATH", pathJoin(nvmathdir, "lib64"))

prepend_path("MANPATH", pathJoin(nvcompdir, "man"))
prepend_path("CMAKE_PREFIX_PATH", pathJoin(nvcudadir))
prepend_path("CMAKE_PREFIX_PATH", pathJoin(nvmathdir))
EOF

echo "NVHPC ${NVHPC_VERSION} module written to ${MODULE_PATH}"
