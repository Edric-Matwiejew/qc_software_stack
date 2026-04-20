#!/bin/bash

source settings.sh

# version and build from download URL at https://developer.nvidia.com/cutensor-downloads
CUTENSOR_ARCH=sbsa

for i in "${!CUTENSOR_VERSIONS[@]}"
do

	CUTENSOR_VERSION=${CUTENSOR_VERSIONS[i]}
	CUTENSOR_BUILD=${CUTENSOR_BUILDS[i]}
	module load nvhpc/$NVHPC_VERSION
	CUDA_MAJOR_VERSION=$(nvcc --version | grep -o "release [0-9]\+\.[0-9]\+" | awk '{split($2, a, "."); print a[1]}')
	
	CUTENSOR_ARCHIVE=libcutensor-linux-${CUTENSOR_ARCH}-${CUTENSOR_VERSION}.${CUTENSOR_BUILD}-archive
	CUTENSOR_INSTALL_PREFIX=$INSTALL_PREFIX/cutensor-${CUTENSOR_VERSION}
	CUTENSOR_MODULE_PREFIX=$MODULE_PREFIX/cutensor

	if [[ -f "$CUTENSOR_INSTALL_PREFIX/include/cutensor.h" ]]; then
		echo "cuTENSOR $CUTENSOR_VERSION already installed. Skipping."
		continue
	fi

	# Clean up any partial install from previous failed attempt
	rm -rf $CUTENSOR_INSTALL_PREFIX

	cd $BUILD_PREFIX

	# download and extract archive (remove stale download first)
	rm -f ${CUTENSOR_ARCHIVE}.tar.xz ${CUTENSOR_ARCHIVE}.tar.xz.*
	wget https://developer.download.nvidia.com/compute/cutensor/redist/libcutensor/linux-${CUTENSOR_ARCH}/$CUTENSOR_ARCHIVE.tar.xz
	tar -xvf ${CUTENSOR_ARCHIVE}.tar.xz
	
	#remove cuda-11 libraries
	#rm -rf ${CUTENSOR_ARCHIVE}/lib/11*
	
	# install
	mkdir -p $CUTENSOR_INSTALL_PREFIX
	mv $CUTENSOR_ARCHIVE/* $CUTENSOR_INSTALL_PREFIX/.
	
	# clean up build files
	rm -rf $CUTENSOR_ARCHIVE*
	
	# create module from template
	MODULE_TEMP_PATH="$MODULE_TEMP_PREFIX/$CUTENSOR_VERSION.lua"
	cp $SETUP_PREFIX/modules/cutensor_module "$MODULE_TEMP_PATH"
	sed -i "s|CUTENSORVERSION|$CUTENSOR_VERSION|g" "$MODULE_TEMP_PATH"
	sed -i "s|NVHPCVERSION|$NVHPC_VERSION|g" "$MODULE_TEMP_PATH"
	sed -i "s|CUDAVERSION|$CUDA_MAJOR_VERSION|g" "$MODULE_TEMP_PATH"
	sed -i "s|CUTENSORROOT|$CUTENSOR_INSTALL_PREFIX|g" "$MODULE_TEMP_PATH"
	
	# install module
	mkdir -p $CUTENSOR_MODULE_PREFIX
	mv "$MODULE_TEMP_PATH" $CUTENSOR_MODULE_PREFIX/.
	
	module unload nvhpc/$NVHPC_VERSION
done
