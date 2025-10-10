#!/usr/bin/env bash

set -e

source "$(dirname "$0")/settings.sh"

module purge
module load pawsey

 Default test script
TEST_SCRIPT=${1:-tests/test_cupy.py}

for PYVER in "${PYTHON_VERSIONS[@]}"; do
    MOD="py-${PYVER}-cupy/${CUPY_VERSION}"
    echo "=== Testing ${MOD} ==="
    module load "${MOD}" || { echo "Failed to load ${MOD}"; continue; }
    python "$TEST_SCRIPT" || echo "Test failed for ${MOD}"
    module unload "${MOD}"
    echo
done

module purge
module load pawsey

TEST_AER=${1:-tests/test_qiskit_aer.py}

echo "=== Qiskit Aer GPU/cuQuantum tests ==="
for PYVER in "${PYTHON_VERSIONS[@]}"; do
    MOD="py-${PYVER}-qiskit-aer/${QISKIT_AER_VERSION}"
    echo "=== Testing ${MOD} ==="
    module load "${MOD}" || { echo "Failed to load ${MOD}"; continue; }
    srun -N 1 --gpus=1 --mem=0 --mpi=pmix python "$TEST_AER" || echo "Test failed for ${MOD}"
    module unload "${MOD}"
    echo
done

# --- cuQuantum Python test runner ---
# Runs test_cuquantum.py for each Python version


TEST_CUQ=${1:-tests/test_cuquantum_python.py}

echo "=== cuQuantum Python package tests ==="
for PYVER in "${PYTHON_VERSIONS[@]}"; do
    module purge
    module load pawsey
    MOD="py-${PYVER}-cuquantum/${CUQUANTUM_PYTHON_VERSION}"
    echo "=== Testing ${MOD} ==="
    module load python/$PYVER
    module load "${MOD}" || { echo "Failed to load ${MOD}"; continue; }
    module list
    python "$TEST_CUQ" || echo "Test failed for ${MOD}"
    module unload "${MOD}"
    echo
done

# --- CUDA-Q (cudaq) test runner ---

TEST_CUDAQ=${1:-test_cudaq.py}

echo "=== CUDA-Q (cudaq) tests ==="
for PYVER in "${PYTHON_VERSIONS[@]}"; do
    MOD="py-${PYVER}-cudaq/${CUDA_QUANTUM_VERSION}"
    echo "=== Testing ${MOD} ==="
    module load "${MOD}" || { echo "Failed to load ${MOD}"; continue; }
    python "$TEST_CUDAQ" || echo "Test failed for ${MOD}"
    module unload "${MOD}"
    echo
done

