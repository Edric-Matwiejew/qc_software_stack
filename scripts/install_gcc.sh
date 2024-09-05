#!/bin/bash

source settings.sh

GCC_INSTALL_PREFIX=$INSTALL_PREFIX/gcc-$GCC_VERSION
GCC_MODULE_PREFIX=$MODULE_PREFIX/gcc
mkdir -p $GCC_MODULE_PREFIX

export TMPDIR=$BUILD_PREFIX/tmp
mkdir -p $TMPDIR

export CC=$HOST_CC
export CXX=$HOST_CXX

cd $BUILD_PREFIX
wget https://ftp.tsukuba.wide.ad.jp/software/gcc/releases/gcc-$GCC_VERSION/gcc-$GCC_VERSION.tar.gz
tar -I pigz -xf gcc-$GCC_VERSION.tar.gz
cd gcc-$GCC_VERSION
./contrib/download_prerequisites
rm -rf objdir && mkdir -p objdir
cd objdir
$BUILD_PREFIX/gcc-$GCC_VERSION/configure --prefix=$GCC_INSTALL_PREFIX
make -j 32
make install

MODULE_TEMP_PATH=$MODULE_TEMP_PREFIX/$GCC_VERSION
cp $SETUP_PREFIX/modules/gcc_module "$MODULE_TEMP_PATH"
sed -i "s|GCCVERSION|$GCC_VERSION|g" "$MODULE_TEMP_PATH"
sed -i "s|GCCROOT|$GCC_INSTALL_PREFIX|g" "$MODULE_TEMP_PATH"
sed -i "s|GCCROOT|$GCC_INSTALL_PREFIX|g" "$MODULE_TEMP_PATH"
mv "$MODULE_TEMP_PATH" "$GCC_MODULE_PREFIX/$GCC_VERSION.lua"


# set the default gcc module
cat <<EOF > .version
#%Module -*- tcl -*-
set ModulesVersion "$GCC_VERSION"
EOF

mv .version "$GCC_MODULE_PREFIX/.version"

