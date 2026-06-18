#!/bin/bash

source settings.sh

# version and build from download URL at https://developer.nvidia.com/cutensor-downloads
CUTENSOR_ARCH=sbsa

module load nvhpc/$NVHPC_VERSION

for i in "${!CUTENSOR_VERSIONS[@]}"
do
	CUTENSOR_VERSION=${CUTENSOR_VERSIONS[i]}
	CUTENSOR_BUILD=${CUTENSOR_BUILDS[i]}
	# cuda12 / cuda13 suffix disambiguates parallel installs of the same version.
	CUDA_SUFFIX=$(echo "$CUTENSOR_BUILD" | grep -oE 'cuda[0-9]+')
	CUDA_MAJOR_VERSION=${CUDA_SUFFIX#cuda}
	CUTENSOR_MODULE_VERSION=${CUTENSOR_VERSION}_${CUDA_SUFFIX}

	CUTENSOR_ARCHIVE=libcutensor-linux-${CUTENSOR_ARCH}-${CUTENSOR_VERSION}.${CUTENSOR_BUILD}-archive
	CUTENSOR_INSTALL_PREFIX=$INSTALL_PREFIX/cutensor-${CUTENSOR_MODULE_VERSION}
	CUTENSOR_MODULE_PREFIX=$MODULE_PREFIX/cutensor

	if [[ -f "$CUTENSOR_INSTALL_PREFIX/include/cutensor.h" ]]; then
		echo "cuTENSOR $CUTENSOR_MODULE_VERSION already installed. Skipping."
		continue
	fi

	rm -rf $CUTENSOR_INSTALL_PREFIX
	cd $BUILD_PREFIX

	rm -f ${CUTENSOR_ARCHIVE}.tar.xz ${CUTENSOR_ARCHIVE}.tar.xz.*
	wget https://developer.download.nvidia.com/compute/cutensor/redist/libcutensor/linux-${CUTENSOR_ARCH}/$CUTENSOR_ARCHIVE.tar.xz
	tar -xf ${CUTENSOR_ARCHIVE}.tar.xz

	mkdir -p $CUTENSOR_INSTALL_PREFIX
	mv $CUTENSOR_ARCHIVE/* $CUTENSOR_INSTALL_PREFIX/.
	rm -rf $CUTENSOR_ARCHIVE*

	MODULE_TEMP_PATH="$MODULE_TEMP_PREFIX/$CUTENSOR_MODULE_VERSION.lua"
	cp $SETUP_PREFIX/modules/cutensor_module "$MODULE_TEMP_PATH"
	sed -i "s|CUTENSORVERSION|$CUTENSOR_MODULE_VERSION|g" "$MODULE_TEMP_PATH"
	sed -i "s|NVHPCVERSION|$NVHPC_VERSION|g"              "$MODULE_TEMP_PATH"
	sed -i "s|CUDAVERSION|$CUDA_MAJOR_VERSION|g"          "$MODULE_TEMP_PATH"
	sed -i "s|CUTENSORROOT|$CUTENSOR_INSTALL_PREFIX|g"    "$MODULE_TEMP_PATH"

	mkdir -p $CUTENSOR_MODULE_PREFIX
	mv "$MODULE_TEMP_PATH" $CUTENSOR_MODULE_PREFIX/.
done

module unload nvhpc/$NVHPC_VERSION
