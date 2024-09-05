#!/bin/bash

source settings.sh

SPACK_VERSION=0.22.1
SPACK_PYTHON_VERSION=$PYTHON_DEFAULT_VERSION
SPACK_INSTALL_PREFIX="$INSTALL_PREFIX/spack-${SPACK_VERSION}"
SPACK_MODULE_PREFIX="$MODULE_PREFIX/spack"
USER_SPACK_PATH="\$MYSOFTWARE/software/$SYSTEM/$DATE_TAG/spack-$SPACK_VERSION"

cd $BUILD_PREFIX
rm -rf spack
git clone --branch=v$SPACK_VERSION -c feature.manyFiles=true https://github.com/spack/spack.git
rm -rf "$SPACK_INSTALL_PREFIX"
mkdir -p "$SPACK_INSTALL_PREFIX"
cp -r spack/* "$SPACK_INSTALL_PREFIX/."

ls $SETUP_PREFIX/spack/etc/*
cp $SETUP_PREFIX/spack/etc/* "$SPACK_INSTALL_PREFIX/etc/spack/."

find "$SPACK_INSTALL_PREFIX/etc/spack" -type f -name "*.yaml" -exec sed -i "s/DATETAG/$DATE_TAG/g" {} +
find "$SPACK_INSTALL_PREFIX/etc/spack" -type f -name "*.yaml" -exec sed -i "s/SYSTEM/$SYSTEM/g" {} +
find "$SPACK_INSTALL_PREFIX/etc/spack" -type f -name "*.yaml" -exec sed -i "s/SPACKVERSION/$SPACK_VERSION/g" {} +

module load gcc
module load python/$SPACK_PYTHON_VERSION
SPACK_PYTHON=$(which python3)

SPACK_MODULE_TEMP_PATH="$MODULE_TEMP_PREFIX/$SPACK_VERSION.lua"
cp "$SETUP_PREFIX/modules/spack_module" "$SPACK_MODULE_TEMP_PATH"
sed -i "s|SPACKVERSION|$SPACK_VERSION|g" "$SPACK_MODULE_TEMP_PATH"
sed -i "s|SPACKINSTALLPATH|$SPACK_INSTALL_PREFIX|g" "$SPACK_MODULE_TEMP_PATH"
sed -i "s|SPACKPYTHONVERSION|$SPACK_PYTHON_VERSION|g" "$SPACK_MODULE_TEMP_PATH" # must replace before below
sed -i "s|SPACKPYTHON|$SPACK_PYTHON|g" "$SPACK_MODULE_TEMP_PATH"
sed -i "s|USERSPACKPATH|$USER_SPACK_PATH|g" "$SPACK_MODULE_TEMP_PATH"
mkdir -p "$SPACK_MODULE_PREFIX"
mv "$SPACK_MODULE_TEMP_PATH" "$SPACK_MODULE_PREFIX"/.


module unload python
