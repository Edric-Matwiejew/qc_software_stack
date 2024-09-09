#!/bin/bash

source settings.sh

# Check if essential variables are set
if [[ -z "$INSTALL_PREFIX" || -z "$GCC_VERSION" || -z "$BUILD_PREFIX" ]]; then
    echo "Required variables are not set. Please check settings.sh."
    exit 1
fi

module load gcc
module load perl

# Build tools installed with the default GCC
export BUILD_TOOLS_INSTALL_PREFIX="$INSTALL_PREFIX/gcc-$GCC_VERSION"
export BUILD_TOOLS_BUILD_PREFIX="$BUILD_PREFIX/gnu-build-tools"
rm -rf "$BUILD_TOOLS_BUILD_PREFIX" && mkdir -p "$BUILD_TOOLS_BUILD_PREFIX" && cd "$BUILD_TOOLS_BUILD_PREFIX" || { echo "Failed to create build directory"; exit 1; }

mkdir -p "$BUILD_TOOLS_INSTALL_PREFIX/bin" "$BUILD_TOOLS_INSTALL_PREFIX/lib" "$BUILD_TOOLS_INSTALL_PREFIX/include"

export PATH="$BUILD_TOOLS_INSTALL_PREFIX/bin:$PATH"
export LD_LIBRARY_PATH="$BUILD_TOOLS_INSTALL_PREFIX/lib:$LD_LIBRARY_PATH"
export CPATH="$BUILD_TOOLS_INSTALL_PREFIX/include:$CPATH"
export LIBRARY_PATH="$BUILD_TOOLS_INSTALL_PREFIX/lib:$LIBRARY_PATH"
export PKG_CONFIG_PATH="$BUILD_TOOLS_INSTALL_PREFIX/lib/pkgconfig:$PKG_CONFIG_PATH"

# Function to download, build, and install packages using 'configure' and 'make'
build_and_install() {
  package_name=$1
  package_url=$2
  package_version=$3
  configure_flags=$4  # Optional additional flags for the configure step

  # Download the package
  cd "$BUILD_TOOLS_BUILD_PREFIX" || exit
  wget "$package_url" || { echo "Failed to download $package_name"; exit 1; }

  # Extract the tarball
  tar -xvf "${package_name}-${package_version}.tar.gz" || { echo "Failed to extract $package_name"; exit 1; }
  cd "${package_name}-${package_version}" || exit

  # Configure, build, and install
  ./configure --help
  CC=$(which gcc) CXX=$(which g++) FC=$(which gfortran) ./configure --prefix="$BUILD_TOOLS_INSTALL_PREFIX" $configure_flags || { echo "Failed to configure $package_name"; exit 1; }
  make -j$(nproc) || { echo "Failed to build $package_name"; exit 1; }
  make install || { echo "Failed to install $package_name"; exit 1; }

  # Clean up the source directory
  cd "$BUILD_TOOLS_BUILD_PREFIX" || exit
  rm -f "${package_name}-${package_version}.tar.gz"
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

# Building SQLite without a function due to naming convention
SQLITE_VERSION=3.46.1
wget "https://github.com/sqlite/sqlite/archive/refs/tags/version-$SQLITE_VERSION.tar.gz" || { echo "Failed to download SQLite"; exit 1; }
tar -xvf "version-$SQLITE_VERSION.tar.gz" || { echo "Failed to extract SQLite"; exit 1; }
cd "sqlite-version-$SQLITE_VERSION" || exit
./configure --prefix="$BUILD_TOOLS_INSTALL_PREFIX" || { echo "Failed to configure SQLite"; exit 1; }
make || { echo "Failed to build SQLite"; exit 1; }
make sqlite3 || { echo "Failed to make sqlite3"; exit 1; }
make install || { echo "Failed to install SQLite"; exit 1; }
cd "$BUILD_TOOLS_BUILD_PREFIX" || exit

# Additional steps for zlib's minizip (CUDA-Q dependency)
export CFLAGS='-fPIC -shared'
build_and_install "zlib" "https://github.com/madler/zlib/releases/download/v1.3/zlib-1.3.tar.gz" "1.3"
cd "$BUILD_TOOLS_BUILD_PREFIX/src/zlib-1.3/contrib/minizip" || exit
autoreconf --install || { echo "Failed to run autoreconf for minizip"; exit 1; }
./configure --prefix="$BUILD_TOOLS_INSTALL_PREFIX" || { echo "Failed to configure minizip"; exit 1; }
make -j$(nproc) all || { echo "Failed to build minizip"; exit 1; }
make install || { echo "Failed to install minizip"; exit 1; }
cd "$BUILD_TOOLS_INSTALL_PREFIX" || exit
export CFLAGS=''

build_and_install "expat" "https://github.com/libexpat/libexpat/releases/download/R_2_6_3/expat-2.6.3.tar.gz" "2.6.3"
build_and_install "libffi" "https://github.com/libffi/libffi/releases/download/v3.4.4/libffi-3.4.4.tar.gz" "3.4.4"

# Build bzip2 manually (no configure script)
wget "https://sourceware.org/pub/bzip2/bzip2-1.0.8.tar.gz" || { echo "Failed to download bzip2"; exit 1; }
tar -xvf "bzip2-1.0.8.tar.gz" || { echo "Failed to extract bzip2"; exit 1; }
cd "bzip2-1.0.8" || exit
sed -i 's/CFLAGS=-Wall -Winline -O2 -g/CFLAGS=-Wall -Winline -O2 -g -fPIC -shared/' Makefile
make -j$(nproc) all || { echo "Failed to build bzip2"; exit 1; }
make install PREFIX="$BUILD_TOOLS_INSTALL_PREFIX" || { echo "Failed to install bzip2"; exit 1; }
cd "$BUILD_TOOLS_BUILD_PREFIX" || exit

# Install OpenSSL
wget "https://www.openssl.org/source/openssl-3.3.1.tar.gz" || { echo "Failed to download OpenSSL"; exit 1; }
tar -xf "openssl-3.3.1.tar.gz" || { echo "Failed to extract OpenSSL"; exit 1; }
cd "openssl-3.3.1" || exit
CC="$CC" CFLAGS="-fPIC" CXX="$CXX" CXXFLAGS="-fPIC" AR="${AR:-ar}" \
perl Configure --prefix="$BUILD_TOOLS_INSTALL_PREFIX" zlib --with-zlib-lib="$BUILD_TOOLS_INSTALL_PREFIX" || { echo "Failed to configure OpenSSL"; exit 1; }
make -j$(nproc) || { echo "Failed to build OpenSSL"; exit 1; }
make install || { echo "Failed to install OpenSSL"; exit 1; }
cd .. && rm -rf "openssl-3.3.1.tar.gz" "openssl-3.3.1"
cd "$BUILD_TOOLS_BUILD_PREFIX" || exit

build_and_install "curl" "https://curl.se/download/curl-8.0.1.tar.gz" "8.0.1"

# Install OpenLDAP
wget "https://github.com/openldap/openldap/archive/refs/tags/OPENLDAP_REL_ENG_2_6_8.tar.gz" || { echo "Failed to download OpenLDAP"; exit 1; }
tar -xvf "OPENLDAP_REL_ENG_2_6_8.tar.gz" || { echo "Failed to extract OpenLDAP"; exit 1; }
cd "openldap-OPENLDAP_REL_ENG_2_6_8" || exit
CC=$(which gcc) CXX=$(which g++) ./configure --prefix="$BUILD_TOOLS_INSTALL_PREFIX" --with-tls=openssl --with-openssl="$BUILD_TOOLS_INSTALL_PREFIX" || { echo "Failed to configure OpenLDAP"; exit 1; }
make -j$(nproc) || { echo "Failed to build OpenLDAP"; exit 1; }
make install || { echo "Failed to install OpenLDAP"; exit 1; }
cd "$BUILD_TOOLS_BUILD_PREFIX" || exit

# Build Git with additional dependencies
build_and_install "git" "https://mirrors.edge.kernel.org/pub/software/scm/git/git-2.43.5.tar.gz" "2.43.5" "--with-curl=$BUILD_TOOLS_INSTALL_PREFIX --with-openssl=$BUILD_TOOLS_INSTALL_PREFIX --with-expat=$BUILD_TOOLS_INSTALL_PREFIX --with-zlib=$BUILD_TOOLS_INSTALL_PREFIX --libexecdir=$BUILD_TOOLS_INSTALL_PREFIX/libexec"
# If I don't do this I can't clone using https?
rm "$BUILD_TOOLS_INSTALL_PREFIX/bin/git"

# Clean up build directory
rm -rf "$BUILD_TOOLS_BUILD_PREFIX"

echo "All packages installed to $BUILD_TOOLS_INSTALL_PREFIX"

echo "Creating ld.so.conf file..."

mkdir -p "$BUILD_TOOLS_INSTALL_PREFIX/etc" "$BUILD_TOOLS_INSTALL_PREFIX/cache"
cat <<EOL > "$BUILD_TOOLS_INSTALL_PREFIX/etc/ld.so.conf"
$BUILD_TOOLS_INSTALL_PREFIX/lib
$BUILD_TOOLS_INSTALL_PREFIX/lib64
/usr/local/lib64
/usr/local/lib
/usr/lib64
/usr/lib
EOL

# Just to be sure...
echo "Running ldconfig with custom configuration..."

ldconfig -f "$BUILD_TOOLS_INSTALL_PREFIX/etc/ld.so.conf" -C "$BUILD_TOOLS_INSTALL_PREFIX/cache/ld.so.cache"
export LD_SO_CACHE="$BUILD_TOOLS_INSTALL_PREFIX/cache/ld.so.cache"

echo "Environment setup complete."

