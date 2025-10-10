#!/usr/bin/env python3
"""
Sanity tests for the cuQuantum Python package.

- cuStateVec: creates an n-qubit GHZ state with GPU statevector ops and checks fidelity.
- cuTensorNet: uses cuquantum.contract (einsum-style) on GPU and checks correctness.

Exit code:
  0 = cuStateVec passed AND (cuTensorNet passed OR not available)
  1 = otherwise
"""

import sys
import math

# --- Dependencies (GPU) ---
try:
    import cupy as cp
except Exception as e:
    print("ERROR: CuPy is required for this test:", repr(e))
    sys.exit(1)

try:
    import numpy as np
    from cuquantum import __version__ as cuq_version
    from cuquantum import custatevec as csv
except Exception as e:
    print("ERROR: cuQuantum (custatevec) import failed:", repr(e))
    sys.exit(1)

# cuTensorNet is optional for this test
try:
    from cuquantum import cutensornet as ctn
    CUTENSORNET_AVAILABLE = True
except Exception:
    CUTENSORNET_AVAILABLE = False

# High-level contraction API (optional but preferred for cuTensorNet test)
try:
    from cuquantum import contract
    CONTRACT_AVAILABLE = True
except Exception:
    CONTRACT_AVAILABLE = False


def banner(msg):
    print("\n" + "=" * 60)
    print(msg)
    print("=" * 60)


def print_env_info():
    print(f"cuQuantum Python version        : {cuq_version}")
    try:
        print(f"custatevec.get_version()       : {csv.get_version()}")
    except Exception:
        pass
    if CUTENSORNET_AVAILABLE:
        try:
            print(f"cutensornet.get_version()      : {ctn.get_version()}")
        except Exception:
            pass
    print(f"CuPy version                    : {cp.__version__}")
    try:
        print(f"CUDA runtime version (cupy)     : {cp.cuda.runtime.runtimeGetVersion()}")
        print(f"Number of GPUs (cupy)           : {cp.cuda.runtime.getDeviceCount()}")
    except Exception:
        pass


# ---------- cuSTATEVEC TEST (GHZ) ----------
def ghz_statevector_test(n_qubits=16, target_fidelity=0.999999):
    """
    Build |GHZ_n> = (|0...0> + |1...1>)/sqrt(2) using cuStateVec on GPU and check fidelity.
    """
    banner("Test 1: cuStateVec (GPU statevector) — GHZ fidelity")

    # Create handle
    handle = csv.create()

    # Statevector: complex128 on GPU
    sv_dtype = cp.complex128
    sv = cp.zeros(1 << n_qubits, dtype=sv_dtype)
    sv[0] = 1.0 + 0.0j  # |0...0>

    # Types for cuStateVec
    CDTYPE = csv.cudaDataType.CUDA_C_64F
    LAYOUT = csv.MatrixLayout.ROW
    COMPUTE = csv.ComputeType.COMPUTE_64F

    # Helpers
    def apply_1q_gate(mat_host, target):
        mat = cp.asarray(mat_host, dtype=sv_dtype)
        csv.apply_matrix(
            handle,
            sv.data.ptr, CDTYPE, n_qubits,
            mat.data.ptr, CDTYPE, LAYOUT, 0,  # adjoint=0
            (target,), 1,
            None, 0, 0,
            COMPUTE
        )

    def apply_2q_gate(mat_host, targets):
        mat = cp.asarray(mat_host, dtype=sv_dtype)
        csv.apply_matrix(
            handle,
            sv.data.ptr, CDTYPE, n_qubits,
            mat.data.ptr, CDTYPE, LAYOUT, 0,
            tuple(targets), 2,
            None, 0, 0,
            COMPUTE
        )

    # H on qubit 0
    H = (1.0 / math.sqrt(2.0)) * np.array([[1, 1], [1, -1]], dtype=np.complex128)
    apply_1q_gate(H, 0)

    # CNOTs: 0->1, 1->2, ..., (n-2)->(n-1) to build GHZ
    CNOT = np.array(
        [[1, 0, 0, 0],
         [0, 1, 0, 0],
         [0, 0, 0, 1],
         [0, 0, 1, 0]], dtype=np.complex128
    )
    for i in range(n_qubits - 1):
        apply_2q_gate(CNOT, (i, i + 1))

    # Expected GHZ amplitudes: only |0...0> and |1...1>
    amp0 = sv[0].get()
    amp1 = sv[-1].get()
    # Normalization is guaranteed by cuStateVec, but be robust:
    norm = float(cp.linalg.norm(sv).get())
    amp0 /= norm
    amp1 /= norm
    F = abs((amp0 + amp1) / math.sqrt(2.0)) ** 2  # overlap^2 with (|0...0>+|1...1>)/sqrt(2)

    print(f"Amplitude |0...0>: {amp0}")
    print(f"Amplitude |1...1>: {amp1}")
    print(f"Fidelity(|psi>, |GHZ>) = {F:.12f}")
    csv.destroy(handle)

    ok = F >= target_fidelity
    print("OK:", ok)
    return ok


# ---------- cuTENSORNET TEST (contract) ----------
def cutensornet_contract_test():
    """
    Test cuTensorNet via cuquantum.contract on GPU:
      Compute C = A @ B and compare to CuPy's matmul.
    """
    banner("Test 2: cuTensorNet (GPU contract) — matrix multiply check")

    if not CUTENSORNET_AVAILABLE or not CONTRACT_AVAILABLE:
        print("cutensornet/contract not available; skipping.")
        return None

    # Small but nontrivial sizes
    m, k, n = 256, 384, 128
    A = cp.random.random((m, k), dtype=cp.float32) + 1j * cp.random.random((m, k), dtype=cp.float32)
    B = cp.random.random((k, n), dtype=cp.float32) + 1j * cp.random.random((k, n), dtype=cp.float32)

    # Einsum with cuTensorNet backend
    C_ctn = contract("ik,kj->ij", A, B)   # uses cuTensorNet
    # Reference (still on GPU)
    C_ref = A @ B

    # Compare on GPU, then bring a scalar diff to host
    diff = float(cp.max(cp.abs(C_ctn - C_ref)).get())
    print("Max |C_ctn - C_ref|:", diff)
    ok = diff <= 1e-3  # loose tolerance for fp32 complex
    print("OK:", ok)
    return ok


def main():
    print_env_info()

    ok_sv = False
    ok_tn = None

    try:
        ok_sv = ghz_statevector_test()
    except Exception as e:
        print("cuStateVec test failed:", repr(e))
        ok_sv = False

    try:
        ok_tn = cutensornet_contract_test()
    except Exception as e:
        print("cuTensorNet contract test failed:", repr(e))
        ok_tn = False
        print(
            "HINT: A version mismatch (e.g., CUTENSORNET_STATUS_CUTENSOR_VERSION_MISMATCH) "
            "usually means the loaded cuTENSOR/cuQuantum runtime does not match what your "
            "environment or wheels were built against. Check your module's LD_LIBRARY_PATH order."
        )

    banner("Summary")
    print(f"cuStateVec (statevector/GPU): {ok_sv}")
    print(f"cuTensorNet (contract/GPU)  : {ok_tn}")

    # Pass if cuStateVec passes and cuTensorNet either passes or is skipped.
    sys.exit(0 if (ok_sv is True and (ok_tn in (True, None))) else 1)


if __name__ == "__main__":
    main()

