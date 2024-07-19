#!/bin/bash

source settings.sh

PYTHON_VERSIONS=( 3.10 3.12 )
PYTHON_DEFAULT_VERSION=3.10
SETUPTOOLS_VERSION=71.0.0
PIP_VERSION=24.1.2
LIBFFI_VERSION=3.4.6 # required for the Python ctypes module

export CC=$HOST_CC
export CXX=$HOST_CXX

mkdir -p $MODULE_PREFIX/python

for PYTHON_VERSION in "${PYTHON_VERSIONS[@]}"
do
	PYTHON_INSTALL_PREFIX=$INSTALL_PREFIX/python-$PYTHON_VERSION
	
	mkdir -p $PYTHON_INSTALL_PREFIX
	
	export PATH=$PYTHON_INSTALL_PREFIX/bin:$PATH
	export CFLAGS="-I$PYTHON_INSTALL_PREFIX/include"
	export LDFLAGS="-L$PYTHON_INSTALL_PREFIX/lib"
	export PKG_CONFIG_PATH="$PYTHON_INSTALL_PREFIX/lib/pkgconfig"
	export LD_LIBRARY_PATH=$PYTHON_INSTALL_PREFIX/lib:$LD_LIBRARY_PATH
	
	cd $BUILD_PREFIX
	
	wget https://github.com/libffi/libffi/releases/download/v$LIBFFI_VERSION/libffi-$LIBFFI_VERSION.tar.gz
	tar -xvf libffi-$LIBFFI_VERSION.tar.gz
	cd libffi-$LIBFFI_VERSION
	./configure --prefix=$PYTHON_INSTALL_PREFIX --enable-debug --disable-docs
	make -j4 all
	make install
	cd $BUILD_PREFIX
	
	git clone --branch $PYTHON_VERSION https://github.com/python/cpython.git
	
	cd cpython
	
	./configure \
	--prefix=$PYTHON_INSTALL_PREFIX \
	--enable-shared=yes \
	--enable-profiling=no \
	--enable-optimizations=yes \
	--with-pydebug=yes \
	--with-ensurepip=install 
	#--with-valgrind=yes
	
	make -j4 all
	make install
	
	ln $PYTHON_INSTALL_PREFIX/bin/python$PYTHON_VERSION $PYTHON_INSTALL_PREFIX/bin/python

	cd $BUILD_PREFIX
	rm -rf cpython liffi*

	MODULE_TEMP_PATH=$MODULE_TEMP_PREFIX/$PYTHON_VERSION
	cp $SETUP_PREFIX/modules/python_module "$MODULE_TEMP_PATH"
	sed -i "s|PYTHONVERSION|$PYTHON_VERSION|g" "$MODULE_TEMP_PATH"
	sed -i "s|COMPILER|gcc-$CC|g" "$MODULE_TEMP_PATH"
	sed -i "s|WHICHPYTHON|$PYTHON_INSTALL_PREFIX/bin/python$PYTHON_VERSION|g" "$MODULE_TEMP_PATH"
	sed -i "s|PYTHONBINARYPATH|$PYTHON_INSTALL_PREFIX/bin|g" "$MODULE_TEMP_PATH"
	sed -i "s|PYTHONLIBRARYPATH|$PYTHON_INSTALL_PREFIX/lib|g" "$MODULE_TEMP_PATH"
	sed -i "s|PYTHONINCLUDE|$PYTHON_INSTALL_PREFIX/include|g" "$MODULE_TEMP_PATH"
	sed -i "s|PYTHONCMAKEPREFIXPATH|$PYTHON_INSTALL_PREFIX|g" "$MODULE_TEMP_PATH"
	sed -i "s|PYTHONMANPATH|$PYTHON_INSTALL_PREFIX/share/man|g" "$MODULE_TEMP_PATH"
	sed -i "s|PYTHONPKGCONFIGPATH|$PYTHON_INSTALL_PREFIX/lib/pkgconfig|g" "$MODULE_TEMP_PATH"
	sed -i "s|DATETAG|$DATE_TAG|g" "$MODULE_TEMP_PATH"

	# ensure that python uses its own pip module and not the version in $HOME/.local
	module load $MODULE_TEMP_PATH
	python3 -m ensurepip
	python3 -m pip install --upgrade pip==$PIP_VERSION
	python3 -m pip install --upgrade setuptools==$SETUPTOOLS_VERSION
	module unload $MODULE_TEMP_PATH

	mv $MODULE_TEMP_PATH $MODULE_PREFIX/python/$PYTHON_VERSION
done

# set the default python module
cat <<EOF > .version
#%Module -*- tcl -*-
set ModulesVersion "$PYTHON_DEFAULT_VERSION"
EOF

mv .version $MODULE_PREFIX/python

