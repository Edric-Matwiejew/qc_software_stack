source settings.sh

# https://docs.nvidia.com/cuda/cuquantum/latest/getting-started/index.html
CUQUANTUM_ARCH=sbsa
CUQUANTUM_VERSION=24.03.0
CUQUANTUM_BUILD_NUMBER=4

module load nvhpc/$NVHPC_VERSION
CUDA_MAJOR_VERSION=$(nvcc --version | grep -o "release [0-9]\+\.[0-9]\+" | awk '{split($2, a, "."); print a[1]}')

CUQUANTUM_INSTALL_PREFIX=$INSTALL_PREFIX/cuquantum-${CUQUANTUM_VERSION}
CUQUANTUM_ARCHIVE=cuquantum-linux-${CUQUANTUM_ARCH}-${CUQUANTUM_VERSION}.${CUQUANTUM_BUILD_NUMBER}_cuda${CUDA_MAJOR_VERSION}-archive
CUQUANTUM_MODULE_PREFIX=$MODULE_PREFIX/cuquantum

cd $BUILD_PREFIX

# get archive and extract
wget https://developer.download.nvidia.com/compute/cuquantum/redist/cuquantum/linux-${CUQUANTUM_ARCH}/$CUQUANTUM_ARCHIVE.tar.xz
tar -xvf $CUQUANTUM_ARCHIVE.tar.xz

# MPI activation
module load mpi/mpich-aarch64
cd $CUQUANTUM_ARCHIVE/distributed_interfaces
$HOST_CC -shared -std=c99 -fPIC \
	-I${NVHPC_ROOT}/cuda/include -I../include -I${MPI_INCLUDE} \
 	 cutensornet_distributed_interface_mpi.c \
  	-L${MPI_LIB} -lmpi \
  	-o libcutensornet_distributed_interface_mpi.so
cd $BUILD_PREFIX

# install
mkdir -p $CUQUANTUM_INSTALL_PREFIX
mv $CUQUANTUM_ARCHIVE/* $CUQUANTUM_INSTALL_PREFIX/.
rm -rf $CUQUANTUM_ARCHIVE.tar.xz

MODULE_TEMP_PATH=$BUILD_PREFIX/$CUQUANTUM_VERSION
cp $SETUP_PREFIX/modules/cuquantum_module $MODULE_TEMP_PATH
sed -i "s|CUQUANTUMVERSION|$CUQUANTUM_VERSION|g" "$MODULE_TEMP_PATH"
sed -i "s|CUDAVERSION|$CUDA_MAJOR_VERSION|g" "$MODULE_TEMP_PATH"
sed -i "s|CUQUANTUMROOT|$CUQUANTUM_INSTALL_PREFIX|g" "$MODULE_TEMP_PATH"
mkdir -p $CUQUANTUM_MODULE_PREFIX
mv $MODULE_TEMP_PATH $CUQUANTUM_MODULE_PREFIX/.
