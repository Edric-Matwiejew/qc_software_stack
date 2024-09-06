#!/bin/bash

source settings.sh

module load gcc
module load perl

# Build tools installed with the default GCC
export BUILD_TOOLS_INSTALL_PREFIX=$INSTALL_PREFIX/gcc-$GCC_VERSION

export BUILD_TOOLS_BUILD_PREFIX=$BUILD_PREFIX/gnu-build-tools
rm -rf $BUILD_TOOLS_BUILD_PREFIX && mkdir $BUILD_TOOLS_BUILD_PREFIX && cd $BUILD_TOOLS_BUILD_PREFIX

mkdir -p $BUILD_TOOLS_INSTALL_PREFIX/bin $BUILD_TOOLS_INSTALL_PREFIX/lib $BUILD_TOOLS_INSTALL_PREFIX/include

export PATH=$BUILD_TOOLS_INSTALL_PREFIX/bin:$PATH
export LD_LIBRARY_PATH=$BUILD_TOOLS_INSTALL_PREFIX/lib:$LD_LIBRARY_PATH
export CPATH=$BUILD_TOOLS_INSTALL_PREFIX/include:$CPATH
export LIBRARY_PATH=$BUILD_TOOLS_INSTALL_PREFIX/lib:$LIBRARY_PATH
export PKG_CONFIG_PATH=$BUILD_TOOLS_INSTALL_PREFIX/lib/pkgconfig:$PKG_CONFIG_PATH

# Function to download, build, and install a packages that use 'configure' and 'make'
build_and_install() {
  package_name=$1
  package_url=$2
  package_version=$3
  configure_flags=$4  # Optional additional flags for the configure step

  # Download the package
  cd $BUILD_TOOLS_BUILD_PREFIX
  wget $package_url

  # Extract the tarball
  tar -xvf ${package_name}-${package_version}.tar.gz
  cd ${package_name}-${package_version}

  # Configure, build, and install
  ./configure --help 
  CC=$(which gcc) CXX=$(which g++) FC=$(which gfortran) ./configure --prefix=$BUILD_TOOLS_INSTALL_PREFIX $configure_flags
  make -j 64
  make install

  # Return to src directory for the next package
  cd $BUILD_TOOLS_BUILD_PREFIX
}

## Build tools
build_and_install "autoconf" "https://ftp.gnu.org/gnu/autoconf/autoconf-2.72.tar.gz" "2.72"
build_and_install "automake" "https://ftp.gnu.org/gnu/automake/automake-1.17.tar.gz" "1.17"
build_and_install "libtool" "https://ftp.gnu.org/gnu/libtool/libtool-2.4.7.tar.gz" "2.4.7"
build_and_install "pkg-config" "https://pkgconfig.freedesktop.org/releases/pkg-config-0.29.2.tar.gz" "0.29.2" "--with-internal-glib"
build_and_install "binutils" "https://ftp.gnu.org/gnu/binutils/binutils-2.43.1.tar.gz" "2.43.1"

# Download and install common dependencies (zlib version chosen for CUDA-Q)
build_and_install "mpdecimal" "https://www.bytereef.org/software/mpdecimal/releases/mpdecimal-4.0.0.tar.gz" "4.0.0"
build_and_install "xz" "https://github.com/tukaani-project/xz/releases/download/v5.6.2/xz-5.6.2.tar.gz" "5.6.2"

# Building without function due to break in naming convension
cd $BUILD_TOOLS_BUILD_PREFIX
SQLITE_VERSION=3.46.1
wget https://github.com/sqlite/sqlite/archive/refs/tags/version-$SQLITE_VERSION.tar.gz
tar -xvf version-*.tar.gz
cd sqlite-version*
./configure --prefix=$BUILD_TOOLS_INSTALL_PREFIX
make
make sqlite3.c
make install
cd $BUILD_TOOLS_BUILD_PREFIX

export CFLAGS='-fPIC -shared'
build_and_install "zlib" "https://github.com/madler/zlib/releases/download/v1.3/zlib-1.3.tar.gz" "1.3"
# Additional steps for zlib's minizip (CUDA-Q dependency)
cd $BUILD_TOOLS_BUILD_PREFIX/src/zlib-1.3/contrib/minizip
autoreconf --install
./configure --prefix=$BUILD_TOOLS_INSTALL_PREFIX
make -j64 all
make install
cd $BUILD_TOOLS_INSTALL_PREFIX

export CFLAGS=''
build_and_install "expat" "https://github.com/libexpat/libexpat/releases/download/R_2_6_3/expat-2.6.3.tar.gz" "2.6.3"

build_and_install "libffi" "https://github.com/libffi/libffi/releases/download/v3.4.4/libffi-3.4.4.tar.gz" "3.4.4"

# bzip2 does not have a 'configure' script
wget https://sourceware.org/pub/bzip2/bzip2-1.0.8.tar.gz
tar -xvf bzip2-1.0.8.tar.gz
cd bzip2-1.0.8
sed -i 's/CFLAGS=-Wall -Winline -O2 -g/CFLAGS=-Wall -Winline -O2 -g -fPIC -shared/' Makefile
cat Makefile
make -j64 all
make install PREFIX=$BUILD_TOOLS_INSTALL_PREFIX

cd $BUILD_TOOLS_BUILD_PREFIX
wget https://www.openssl.org/source/openssl-3.3.1.tar.gz
tar -xf openssl-3.3.1.tar.gz && cd openssl-3.3.1
CC="$CC" CFLAGS="-fPIC" CXX="$CXX" CXXFLAGS="-fPIC" AR="${AR:-ar}" \
perl Configure --prefix="$BUILD_TOOLS_INSTALL_PREFIX" zlib --with-zlib-lib="$BUILD_TOOLS_INSTALL_PREFIX"
make -j64 && make install
cd .. && rm -rf openssl-3.3.1.tar.gz openssl-3.3.1

build_and_install "curl" "https://curl.se/download/curl-8.0.1.tar.gz" "8.0.1"

cd $BUILD_TOOLS_BUILD_PREFIX
wget https://github.com/openldap/openldap/archive/refs/tags/OPENLDAP_REL_ENG_2_6_8.tar.gz
tar -xvf OPENLDAP_REL_ENG_2_6_8.tar.gz
cd openldap-OPENLDAP_REL_ENG_2_6_8
CC=$(which gcc) CXX=$(which g++) ./configure --prefix=$BUILD_TOOLS_INSTALL_PREFIX --with-tls=openssl --with-openssl=$BUILD_TOOLS_INSTALL_PREFIX
make -j64
make install

build_and_install "git" "https://mirrors.edge.kernel.org/pub/software/scm/git/git-2.43.5.tar.gz" "2.43.5" "--with-curl=$BUILD_TOOLS_INSTALL_PREFIX --with-openssl=$BUILD_TOOLS_INSTALL_PREFIX --with-expat=$BUILD_TOOLS_INSTALL_PREFIX --with-zlib=$BUILD_TOOLS_INSTALL_PREFIX --libexecdir=$BUILD_TOOLS_INSTALL_PREFIX/libexec"
# If I don't do this I can't clone using https?
rm $BUILD_TOOLS_INSTALL_PREFIX/bin/git

rm -rf $BUILD_TOOLS_BUILD_PREFIX

echo "All packages installed to $BUILD_TOOLS_INSTALL_PREFIX"

echo "Creating ld.so.conf file..."

mkdir -p $BUILD_TOOLS_INSTALL_PREFIX/etc
mkdir -p $BUILD_TOOLS_INSTALL_PREFIX/cache
cat <<EOL > $BUILD_TOOLS_INSTALL_PREFIX/etc/ld.so.conf
$BUILD_TOOLS_INSTALL_PREFIX/lib
$BUILD_TOOLS_INSTALL_PREFIX/lib64
/usr/local/lib64
/usr/local/lib
/usr/lib64
/usr/lib
EOL

# Just to be sure...
echo "Running ldconfig with custom configuration..."

ldconfig -f $BUILD_TOOLS_INSTALL_PREFIX/etc/ld.so.conf -C $BUILD_TOOLS_INSTALL_PREFIX/cache/ld.so.cache
export LD_SO_PRELOAD=$BUILD_TOOLS_INSTALL_PREFIX/cache/ld.so.cache

echo "Environment setup complete."
