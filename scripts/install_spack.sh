#!/bin/bash

source settings.sh

SPACK_REPO="https://github.com/spack/spack.git"

SPACK_PYTHON_VERSION=$PYTHON_DEFAULT_VERSION
SPACK_INSTALL_PREFIX="$INSTALL_PREFIX/spack-${SPACK_VERSION}"
SPACK_MODULE_PREFIX="$MODULE_PREFIX/spack"
USER_SPACK_PATH="software/$SYSTEM/$DATE_TAG/spack-$SPACK_VERSION"

# Clean up any existing installation
rm -rf "$SPACK_INSTALL_PREFIX"

# Clone Spack directly into the installation directory
git clone --branch=v$SPACK_VERSION -c feature.manyFiles=true "$SPACK_REPO" "$SPACK_INSTALL_PREFIX"

# Copy configuration files from setup directory
if [ -d "$SETUP_PREFIX/spack/etc" ]; then
    cp -r "$SETUP_PREFIX/spack/etc/." "$SPACK_INSTALL_PREFIX/etc/spack/"
fi

# Update placeholders in YAML configuration files
find "$SPACK_INSTALL_PREFIX/etc/spack" -type f -name "*.yaml" -exec sed -i "s/DATETAG/$DATE_TAG/g" {} +
find "$SPACK_INSTALL_PREFIX/etc/spack" -type f -name "*.yaml" -exec sed -i "s/SYSTEM/$SYSTEM/g" {} +
find "$SPACK_INSTALL_PREFIX/etc/spack" -type f -name "*.yaml" -exec sed -i "s/SPACKVERSION/$SPACK_VERSION/g" {} +

# Load necessary modules
module load gcc/$GCC_VERSION
module load python/$SPACK_PYTHON_VERSION
SPACK_PYTHON=$(which python3)

# Install dependencies
python -m pip install --upgrade patchelf certifi

# Ensure `patchelf` updates the RPATH for Python
patchelf --set-rpath "$(dirname $(which python))/../lib" "$(which python)"

# Update compiler configuration in Spack
SPACK_COMPILERS_FILE="$SPACK_INSTALL_PREFIX/etc/spack/compilers.yaml"
sed -i "s|GCCVERSION|$GCC_VERSION|g" "$SPACK_COMPILERS_FILE"
sed -i "s|CCBINARY|$(which gcc)|g" "$SPACK_COMPILERS_FILE"
sed -i "s|CXXBINARY|$(which g++)|g" "$SPACK_COMPILERS_FILE"
sed -i "s|F77BINARY|$(which gfortran)|g" "$SPACK_COMPILERS_FILE"
sed -i "s|F90BINARY|$(which gfortran)|g" "$SPACK_COMPILERS_FILE"
sed -i "s|PYTHONVERSION|$SPACK_PYTHON_VERSION|g" "$SPACK_COMPILERS_FILE"

# Set up module file for Spack
SPACK_MODULE_TEMP_PATH="$MODULE_TEMP_PREFIX/$SPACK_VERSION.lua"
cp "$SETUP_PREFIX/modules/spack_module" "$SPACK_MODULE_TEMP_PATH"
sed -i "s|SPACKVERSION|$SPACK_VERSION|g" "$SPACK_MODULE_TEMP_PATH"
sed -i "s|SPACKINSTALLPATH|$SPACK_INSTALL_PREFIX|g" "$SPACK_MODULE_TEMP_PATH"
sed -i "s|PYTHONVERSION|$SPACK_PYTHON_VERSION|g" "$SPACK_MODULE_TEMP_PATH" # Replace before SPACKPYTHON
sed -i "s|SPACKPYTHON|$SPACK_PYTHON|g" "$SPACK_MODULE_TEMP_PATH"
sed -i "s|USERSPACKPATH|$USER_SPACK_PATH|g" "$SPACK_MODULE_TEMP_PATH"
sed -i "s|SSLCERTFILE|$(python -m certifi)|g" "$SPACK_MODULE_TEMP_PATH"

# Move module file to the final location
mkdir -p "$SPACK_MODULE_PREFIX"
mv "$SPACK_MODULE_TEMP_PATH" "$SPACK_MODULE_PREFIX/."

# Unload modules
module unload python
module unload gcc

