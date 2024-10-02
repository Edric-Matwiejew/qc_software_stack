#!/bin/bash

source settings.sh

module load nvhpc/$NVHPC_VERSION
module load hpcx-mt-ompi
module load gcc/$GCC_VERSION

JULIA_VERSION=1.10.5
JULIA_CUDA_VERSION=5.4.3

JULIA_BUILD_PREFIX=$BUILD_PREFIX/julia
mkdir -p $JULIA_BUILD_PREFIX
JULIA_INSTALL_PREFIX=$INSTALL_PREFIX/julia-${JULIA_VERSION}
mkdir -p $JULIA_INSTALL_PREFIX
JULIA_MODULE_PREFIX=$MODULE_PREFIX/julia
mkdir -p $JULIA_MODULE_PREFIX

JULIA_INSTALL_PATH=$JULIA_INSTALL_PREFIX/julia

PATH=$JULIA_INSTALL_PATH/bin:$PATH

# variables must be exported for package installs
export JULIA_PROJECT=$JULIA_INSTALL_PREFIX/site-project
export JULIA_DEPOT_PATH=$JULIA_INSTALL_PREFIX/site-depot
export JULIA_CUDA_LIBRARY_PATH=$NVHPC_ROOT/cuda
export JULIA_CXXFLAGS="-O3 -march=native -I$GCC_ROOT/include -I$NVHPC_ROOT/cuda/include"
export JULIA_LDFLAGS="-L$GCC_ROOT/lib -L$GCC_ROOT/lib64 -L$NVHPC_ROOT/cuda/lib64"

USER_JULIA_PATH=software/ella/$DATE_TAG/julia-${JULIA_VERSION}

#mkdir -p $JULIA_INSTALL_PATH $JULIA_DEPOT_PATH $JULIA_LOAD_PATH

cd $JULIA_BUILD_PATH
wget https://julialang-s3.julialang.org/bin/linux/aarch64/${JULIA_VERSION:0:4}/julia-${JULIA_VERSION}-linux-aarch64.tar.gz
tar -xf julia-${JULIA_VERSION}-linux-aarch64.tar.gz
cp -r julia-${JULIA_VERSION}/* $JULIA_INSTALL_PATH/.

cd $BUILD_PREFIX && rm -rf $JULIA_BUILD_PREFIX


# https://cuda.juliagpu.org/stable/installation/overview/#InstallationOverview
JULIA_DEBUG=Pkg julia -e "using Pkg; Pkg.add(PackageSpec(name=\"CUDA\",version=\"$JULIA_CUDA_VERSION\"))"
JULIA_DEBUG=Pkg julia -e "using CUDA; CUDA.set_runtime_version!(local_toolkit=true)"
JULIA_DEBUG=Pkg julia -e "using CUDA; CUDA.versioninfo()"

JULIA_DEBUG=Pkg julia -e "using Pkg; Pkg.add(\"MPI\")"
JULIA_DEBUG=Pkg julia -e 'using Pkg; Pkg.add("MPIPreferences")'
JULIA_DEBUG=Pkg julia -e 'using MPIPreferences; MPIPreferences.use_system_binary()'

JULIA_DEBUG=Pkg julia -e 'using Pkg; Pkg.update()'

MODULE_TEMP_PATH=$MODULE_TEMP_PREFIX/$JULIA_VERSION
cp $SETUP_PREFIX/modules/julia_module "$MODULE_TEMP_PATH"
sed -i "s|JULIAVERSIONMAJORMINOR|${JULIA_VERSION:0:4}|g" "$MODULE_TEMP_PATH"
sed -i "s|JULIAVERSION|$JULIA_VERSION|g" "$MODULE_TEMP_PATH"
sed -i "s|JULIAROOT|$JULIA_INSTALL_PATH|g" "$MODULE_TEMP_PATH"
sed -i "s|JULIAPROJECT|$JULIA_PROJECT|g" "$MODULE_TEMP_PATH"
sed -i "s|JULIADEPOTPATH|$JULIA_DEPOT_PATH|g" "$MODULE_TEMP_PATH"
sed -i "s|USERJULIAPATH|$USER_JULIA_PATH|g" "$MODULE_TEMP_PATH"
sed -i "s|JULIACXXFLAGS|$JULIA_CXXFLAGS|g" "$MODULE_TEMP_PATH"
sed -i "s|JULIALDFLAGS|$JULIA_LDFLAGS|g" "$MODULE_TEMP_PATH"
sed -i "s|NVHPCVERSION|$NVHPC_VERSION|g" "$MODULE_TEMP_PATH"
sed -i "s|GCCVERSION|$GCC_VERSION|g" "$MODULE_TEMP_PATH"

mv $MODULE_TEMP_PATH $JULIA_MODULE_PREFIX/$JULIA_VERSION.lua

module load gcc/$GCC_VERSION
module load hpcx-mt-ompi
module load nvhpc/$NVHPC_VERSION


