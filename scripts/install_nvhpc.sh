#!/bin/bash

source settings.sh

NVHPC_ARCH=Linux_aarch64
NVHPC_YEAR=$(echo $NVHPC_VERSION | cut -d. -f1)
NVHPC_MINOR=$(echo $NVHPC_VERSION | cut -d. -f2)
NVHPC_YEAR_FULL="20${NVHPC_YEAR}"
NVHPC_TAG="${NVHPC_YEAR}${NVHPC_MINOR}"

NVHPC_INSTALL_PREFIX=$INSTALL_PREFIX/nvhpc-${NVHPC_VERSION}
# The multi-CUDA archive bundles both CUDA 12.x and CUDA 13.x under one NVHPC
# install. NVIDIA's installer generates variant module files
# (nvhpc-nompi-cuda12, nvhpc-hpcx-cuda13, etc.) that we expose via symlink below.
NVHPC_CUDA_VERSION=multi
NVHPC_ARCHIVE=nvhpc_${NVHPC_YEAR_FULL}_${NVHPC_TAG}_${NVHPC_ARCH}_cuda_${NVHPC_CUDA_VERSION}

if [[ -d "$NVHPC_INSTALL_PREFIX/${NVHPC_ARCH}/${NVHPC_VERSION}" ]]; then
    echo "NVHPC ${NVHPC_VERSION} already installed at ${NVHPC_INSTALL_PREFIX}. Skipping."
else
    echo "Installing NVHPC ${NVHPC_VERSION}..."
    # BUILD_PREFIX is per-node /tmp; a previous run as a different user can leave
    # it owned by someone else. Fail loudly instead of getting Permission denied
    # halfway through the 14 GB download.
    mkdir -p "$BUILD_PREFIX" 2>/dev/null
    if [ ! -w "$BUILD_PREFIX" ]; then
        echo "ERROR: $BUILD_PREFIX is not writable by $(id -un) (owner=$(stat -c '%U' "$BUILD_PREFIX" 2>/dev/null)). Clean it on this node and re-run." >&2
        exit 1
    fi
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

    # Poll the chunk sizes every 30s while downloads are in flight, so the
    # slurm log shows progress instead of a 5-15 min silent gap.
    while kill -0 "${PIDS[@]}" 2>/dev/null; do
        sleep 30
        DONE=$(du -bc part_* 2>/dev/null | tail -1 | awk '{print $1}')
        [ -n "$DONE" ] && printf '  ... %d / %d MB (%d%%)\n' \
            $((DONE/1024/1024)) $((FILESIZE/1024/1024)) $((DONE * 100 / FILESIZE))
    done
    wait "${PIDS[@]}"

    echo "Merging chunks and extracting..."
    cat $(seq 0 $(( NTHREADS - 1 )) | sed 's/^/part_/') > ${NVHPC_ARCHIVE}.tar.gz
    rm -f part_*

    tar -xzf ${NVHPC_ARCHIVE}.tar.gz
    echo "Running NVIDIA installer..."

    # Auto-answer installer prompts:
    # 1. Enter to continue past header
    # 2. "1" for single-system install
    # 3. Custom installation directory
    printf "\n1\n${NVHPC_INSTALL_PREFIX}\n" | \
        ${NVHPC_ARCHIVE}/install

    cd $BUILD_PREFIX
    rm -rf ${NVHPC_ARCHIVE}.tar.gz ${NVHPC_ARCHIVE}
fi

# NVIDIA's installer generated <prefix>/modulefiles/{nvhpc,nvhpc-nompi,
# nvhpc-hpcx,nvhpc-*-cuda12,nvhpc-*-cuda13,...}/26.3. They're added to
# MODULEPATH by settings.sh; nothing to write here.
echo "NVHPC ${NVHPC_VERSION} modules available at ${NVHPC_INSTALL_PREFIX}/modulefiles"
