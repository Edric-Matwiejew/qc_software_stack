source settings.sh

CMAKE_VERSIONS=( 3.22.1 )

cd $BUILD_PREFIX

module load python

mkdir -p $MODULE_PREFIX/cmake

export CC=$HOST_CC
export CXX=$HOST_CXX
export FC=$HOST_FC

for CMAKE_VERSION in "${CMAKE_VERSIONS[@]}"
do

	CMAKE_INSTALL_PREFIX=$INSTALL_PREFIX/cmake-$CMAKE_VERSION
	mkdir -p $CMAKE_INSTALL_PREFIX

	git clone --branch v$CMAKE_VERSION https://github.com/Kitware/CMake

	cd CMake

	./bootstrap --prefix=$CMAKE_INSTALL_PREFIX
	make -j4
	make install
	cd $BUILD_PREFIX ; rm -rf cmake

	MODULE_TEMP_PATH=$MODULE_TEMP_PREFIX/$CMAKE_VERSION
	cp $SETUP_PREFIX/modules/cmake_module "$MODULE_TEMP_PATH"
	sed -i "s|CMAKEVERSION|$CMAKE_VERSION|g" "$MODULE_TEMP_PATH"
	sed -i "s|COMPILER|gcc-$CC|g" "$MODULE_TEMP_PATH"
	sed -i "s|WHICHCMAKE|$CMAKE_INSTALL_PREFIX/bin/cmake|g" "$MODULE_TEMP_PATH"
	sed -i "s|CMAKEINSTALLPATH|$CMAKE_INSTALL_PREFIX|g" "$MODULE_TEMP_PATH"

	mv $MODULE_TEMP_PATH $MODULE_PREFIX/cmake/$CMAKE_VERSION

done
