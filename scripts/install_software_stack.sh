#!/bin/bash

if [ ! -f "$(pwd)/settings.sh" ] || [ ! -d "$(pwd)/modules" ] || [ ! -d "$(pwd)/scripts" ]; then
    echo "ERROR: settings.sh, modules or scripts not found.\nScript not called from setup root directory."
    exit 1
fi

source settings.sh

#bash scripts/install_python.sh
#bash scripts/install_cmake.sh
#bash scripts/install_ninja.sh
#bash scripts/install_cutensor.sh
bash scripts/install_cuquantum.sh
#bash scripts/install_cudaq.sh

rm -rf $BUILD_PREFIX
