#!/bin/bash --login
#SBATCH --account=pawsey0001
#SBATCH --partition=gpu
#SBATCH --time=00:30:00
#SBATCH --nodes=2
#SBATCH --ntasks-per-node=1
#SBATCH --gpus-per-node=1
#SBATCH --mem=0
#SBATCH --job-name=qc_stack_tests
#SBATCH --exclusive
#SBATCH --exclude=ella-n006,ella-n007
#
# Submit with `sbatch run_tests.sh`, or run interactively on the login node
# with `bash run_tests.sh`. The #SBATCH directives reserve 2 GPU nodes × 1
# GPU each; MPI tests consume the full allocation.

# Drop login-shell env vars that leak the 2024.10 stack into Python 3.12.
unset INSTALL_PREFIX MODULE_PREFIX PYTHONPATH PYTHONUSERBASE

# Under sbatch the script lives in /var/spool/slurm/, so fall back to SUBMIT_DIR.
cd "${SLURM_SUBMIT_DIR:-$(dirname "$(readlink -f "$0")")}"

source settings.sh

PASS=0
FAIL=0

run_test() {
    # run_test <label> <module> <command...>
    local label="$1"
    local mod="$2"
    shift 2
    echo
    echo "=== ${label} (${mod}) ==="
    module purge
    module load pawsey
    if ! module load "${mod}"; then
        echo "  FAIL: ${mod} failed to load (see error above)."
        FAIL=$((FAIL + 1))
        return
    fi
    if "$@"; then
        echo "  PASS: ${mod}"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: ${mod}"
        FAIL=$((FAIL + 1))
    fi
    module unload "${mod}" 2>/dev/null || true
}

for PYVER in "${PYTHON_VERSIONS[@]}"; do
    run_test "CuPy" "py-${PYVER}-cupy/${CUPY_VERSION}" \
        srun -N 1 -n 1 --gpus=1 --mem=0 --export=ALL python tests/test_cupy.py
done

for PYVER in "${PYTHON_VERSIONS[@]}"; do
    run_test "Qiskit Aer (single-rank)" "py-${PYVER}-qiskit-aer/${QISKIT_AER_VERSION}" \
        srun -N 1 -n 1 --gpus=1 --mem=0 --export=ALL python tests/test_qiskit_aer.py
done

for PYVER in "${PYTHON_VERSIONS[@]}"; do
    run_test "Qiskit Aer (MPI 2-rank)" "py-${PYVER}-qiskit-aer/${QISKIT_AER_VERSION}" \
        srun -N 2 --ntasks-per-node=1 --gpus-per-node=1 --mem=0 --mpi=pmix --export=ALL \
        bash -lc "module load py-${PYVER}-mpi4py/${MPI4PY_VERSION} && python tests/test_qiskit_aer.py"
done

for PYVER in "${PYTHON_VERSIONS[@]}"; do
    run_test "cuQuantum Python" "py-${PYVER}-cuquantum/${CUQUANTUM_PYTHON_VERSION}" \
        srun -N 1 -n 1 --gpus=1 --mem=0 --export=ALL python tests/test_cuquantum_python.py
done

# CUDA-Q disabled — see settings.sh CUDA_QUANTUM_VERSION.
# for PYVER in "${PYTHON_VERSIONS[@]}"; do
#     run_test "CUDA-Q" "py-${PYVER}-cudaq/${CUDA_QUANTUM_VERSION}" \
#         srun -N 1 -n 1 --gpus=1 --mem=0 --export=ALL python tests/test_cudaq.py
# done

# variant_id | PL device name | needs GPU | needs MPI
PL_VARIANTS=(
    "kokkos-omp|lightning.kokkos|0|0"
    "gpu|lightning.gpu|1|0"
    "gpu-mpi|lightning.gpu|1|1"
    "tensor|lightning.tensor|1|0"
)
for PYVER in "${PYTHON_VERSIONS[@]}"; do
    PY_MINOR=${PYVER#*.}; PY_MINOR=${PY_MINOR%%.*}
    # PennyLane-Lightning v0.44 requires Python >= 3.11.
    if [[ "$PY_MINOR" -lt 11 ]]; then
        echo
        echo "=== PennyLane Lightning (skipped: Python ${PYVER} < 3.11) ==="
        continue
    fi
    for V in "${PL_VARIANTS[@]}"; do
        IFS='|' read -r VID DEV NEEDS_GPU NEEDS_MPI <<< "$V"
        MOD="py-${PYVER}-pennylane-lightning-${VID}/${PENNYLANE_LIGHTNING_VERSION}"
        if [[ "$NEEDS_MPI" == "1" ]]; then
            PL_DEVICE="$DEV" PL_USE_MPI=1 run_test "PennyLane-Lightning ${VID}" "$MOD" \
                srun -N 2 --ntasks-per-node=1 --gpus-per-node=1 --mem=0 --mpi=pmix --export=ALL \
                bash -lc "module load py-${PYVER}-mpi4py/${MPI4PY_VERSION} && python tests/test_pennylane_lightning.py"
        else
            PL_DEVICE="$DEV" run_test "PennyLane-Lightning ${VID}" "$MOD" \
                srun -N 1 -n 1 --gpus=1 --mem=0 --export=ALL \
                python tests/test_pennylane_lightning.py
        fi
    done
done


echo
echo "==================== Summary ===================="
echo "  PASS: $PASS"
echo "  FAIL: $FAIL"
echo "================================================="
[[ "$FAIL" -eq 0 ]]
