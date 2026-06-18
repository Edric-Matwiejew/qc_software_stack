source settings.sh

cd $BUILD_PREFIX

module load gcc
module load python

mkdir -p $MODULE_PREFIX/cmake

export CC=$(which gcc)
export CXX=$(which g++)
export FC=$(which gfortran)

for CMAKE_VERSION in "${CMAKE_VERSIONS[@]}"
do

	CMAKE_INSTALL_PREFIX=$INSTALL_PREFIX/cmake-$CMAKE_VERSION

	if [[ -d "$CMAKE_INSTALL_PREFIX" ]]; then
		echo "CMake $CMAKE_VERSION already installed. Skipping."
		continue
	fi
	mkdir -p $CMAKE_INSTALL_PREFIX

	git clone --depth 1 --branch v$CMAKE_VERSION https://github.com/Kitware/CMake

	cd CMake

	./bootstrap --prefix=$CMAKE_INSTALL_PREFIX
	make -j64
	make install
	cd $BUILD_PREFIX ; rm -rf cmake

	MODULE_TEMP_PATH=$MODULE_TEMP_PREFIX/$CMAKE_VERSION
	cp $SETUP_PREFIX/modules/cmake_module "$MODULE_TEMP_PATH"
	sed -i "s|CMAKEVERSION|$CMAKE_VERSION|g" "$MODULE_TEMP_PATH"
	sed -i "s|COMPILER|gcc-$CC|g" "$MODULE_TEMP_PATH"
	sed -i "s|WHICHCMAKE|$CMAKE_INSTALL_PREFIX/bin/cmake|g" "$MODULE_TEMP_PATH"
	sed -i "s|CMAKEINSTALLPATH|$CMAKE_INSTALL_PREFIX|g" "$MODULE_TEMP_PATH"

	mv $MODULE_TEMP_PATH $MODULE_PREFIX/cmake/$CMAKE_VERSION.lua

done

# Pin the default cmake module to $CMAKE_VERSION so `module load cmake` (without
# version) doesn't pick a stale higher-numbered .lua left from a previous bump.
cat <<EOF > "$MODULE_PREFIX/cmake/.version"
#%Module -*- tcl -*-
set ModulesVersion "$CMAKE_VERSION"
EOF
