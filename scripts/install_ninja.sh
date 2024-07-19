source settings.sh

module load cmake

NINJA_VERSION=1.11.1

NINJA_INSTALL_PREFIX=$INSTALL_PREFIX/ninja-$NINJA_VERSION

mkdir -p $MODULE_PREFIX/ninja
mkdir -p $NINJA_INSTALL_PREFIX/bin

cd $BUILD_PREFIX

#wget https://github.com/ninja-build/ninja/releases/download/v$NINJA_VERSION/ninja-linux-aarch64.zip
#unzip ninja-linux-aarch64.zip -d $NINJA_INSTALL_PREFIX
#
#rm -rf ninja*

wget https://github.com/ninja-build/ninja/archive/refs/tags/v$NINJA_VERSION.tar.gz
tar -xzvf v$NINJA_VERSION.tar.gz && cd ninja-$NINJA_VERSION
cmake -B build && cmake --build build
ls build
mv build/ninja $NINJA_INSTALL_PREFIX/bin/.
ls $NINJA_INSTALL_PREFIX/bin
rm -rf v$NINJA_VERSION.tar.gz ninja-$NINJA_VERSION


MODULE_TEMP_PATH=$MODULE_TEMP_PREFIX/$NINJA_VERSION
cp $SETUP_PREFIX/modules/ninja_module "$MODULE_TEMP_PATH"
sed -i "s|NINJAVERSION|$NINJA_VERSION|g" "$MODULE_TEMP_PATH"
sed -i "s|WHICHNINJA|$NINJA_INSTALL_PREFIX/bin/ninja|g" "$MODULE_TEMP_PATH"
sed -i "s|NINJAINSTALLPATH|$NINJA_INSTALL_PREFIX|g" "$MODULE_TEMP_PATH"

mv $MODULE_TEMP_PATH $MODULE_PREFIX/ninja/$NINJA_VERSION
