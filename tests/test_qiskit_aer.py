#!/usr/bin/env python3
"""
Qiskit Aer sanity test.

Single-rank mode: cuStateVec (statevector) on GPU + cuTensorNet smoke test.
MPI mode (size > 1): distributed state-vector via Aer's `blocking_enable=True`.

AER_TN_QUBITS overrides the tensor_network circuit size (default 4 — the
legacy contraction path qiskit-aer 0.17.2 uses is broken on cuQuantum 26.x
for n>=8, so this stack pins cuQuantum 25.11.1).
"""

import math
import os
import sys

from qiskit import QuantumCircuit
from qiskit_aer import AerSimulator


def banner(msg):
    print("\n" + "=" * 60)
    print(msg)
    print("=" * 60, flush=True)


def detect_mpi():
    """Return (rank, size) if running under MPI, else (0, 1)."""
    try:
        from mpi4py import MPI  # type: ignore
    except ImportError:
        return 0, 1
    # mpi4py auto-calls MPI_Init on import.
    comm = MPI.COMM_WORLD
    return comm.Get_rank(), comm.Get_size()


def make_ghz(n):
    qc = QuantumCircuit(n, n)
    qc.h(0)
    for i in range(n - 1):
        qc.cx(i, i + 1)
    qc.barrier()
    qc.measure(range(n), range(n))
    return qc


def check_ghz_counts(counts, n, shots, tol=0.15):
    z = counts.get("0" * n, 0)
    o = counts.get("1" * n, 0)
    ok = (z + o) >= (1 - tol) * shots and abs(z - o) <= tol * shots
    return ok, z, o


def probe_capabilities():
    probe = AerSimulator()
    methods = set(probe.available_methods())
    devices = set(probe.available_devices())
    print("Available methods:", sorted(methods))
    print("Available devices:", sorted(devices))
    return methods, devices


# --------------------------------------------------------------------------
# Tests
# --------------------------------------------------------------------------
def run_statevector_gpu_single(n=16, shots=2048):
    banner("Test: cuStateVec (statevector on GPU, single-rank)")
    methods, devices = probe_capabilities()
    if "statevector" not in methods or "GPU" not in devices:
        print("Statevector/GPU not available; skipping.")
        return None
    sim = AerSimulator(
        method="statevector",
        device="GPU",
        precision="double",
        cuStateVec_enable=True,
    )
    qc = make_ghz(n)
    result = sim.run(qc, shots=shots, seed_simulator=42).result()
    counts = result.get_counts()
    ok, c0, c1 = check_ghz_counts(counts, n, shots)
    print(f"Zeros={c0}, Ones={c1}, shots={shots}, OK={ok}")
    return ok


def run_statevector_gpu_mpi(rank, size, n=20, shots=2048):
    """Distributed GPU state-vector via Aer's blocking mode.

    Aer splits the state vector across `size` GPU ranks when blocking_enable=True.
    `blocking_qubits` controls how the state is distributed; use n-2 as a small
    sensible default (log2 of ranks == 2 chunks per rank).
    """
    banner(f"Test: cuStateVec (statevector/GPU + MPI, rank {rank}/{size})")
    blocking_qubits = max(n - int(math.log2(size)), 1)
    sim = AerSimulator(
        method="statevector",
        device="GPU",
        precision="double",
        cuStateVec_enable=True,
        blocking_enable=True,
        blocking_qubits=blocking_qubits,
    )
    qc = make_ghz(n)
    result = sim.run(qc, shots=shots, seed_simulator=42).result()
    counts = result.get_counts()
    ok, c0, c1 = check_ghz_counts(counts, n, shots)
    if rank == 0:
        print(f"Zeros={c0}, Ones={c1}, shots={shots}, blocking_qubits={blocking_qubits}, OK={ok}")
    return ok


def run_tensor_network_gpu(n=4, shots=128):
    """Smoke test of Aer's cuTensorNet backend."""
    banner(f"Test: cuTensorNet (tensor_network on GPU, n={n})")
    methods, devices = probe_capabilities()
    if "tensor_network" not in methods or "GPU" not in devices:
        print("tensor_network/GPU not available; skipping.")
        return None
    sim = AerSimulator(method="tensor_network", device="GPU", precision="double")
    qc = make_ghz(n)
    result = sim.run(qc, shots=shots, seed_simulator=123).result()
    counts = result.get_counts()
    ok, c0, c1 = check_ghz_counts(counts, n, shots)
    print(f"Zeros={c0}, Ones={c1}, shots={shots}, OK={ok}")
    return ok


# --------------------------------------------------------------------------
# Main
# --------------------------------------------------------------------------
def main():
    rank, size = detect_mpi()
    mpi_mode = size > 1

    if rank == 0:
        banner(f"qiskit-aer sanity test — MPI {'ON' if mpi_mode else 'OFF'} "
               f"(rank {rank}/{size})")

    ok_sv = None
    try:
        if mpi_mode:
            ok_sv = run_statevector_gpu_mpi(rank, size)
        else:
            ok_sv = run_statevector_gpu_single()
    except Exception as e:
        print(f"[rank {rank}] statevector test failed:", repr(e))
        ok_sv = False

    ok_tn = None
    if not mpi_mode:
        # tensor_network is single-rank only; skip under MPI.
        try:
            ok_tn = run_tensor_network_gpu(n=int(os.environ.get("AER_TN_QUBITS", "4")))
        except Exception as e:
            print("tensor_network test failed:", repr(e))
            ok_tn = False

    if rank == 0:
        banner("Summary")
        print(f"mpi_mode={mpi_mode}")
        print(f"statevector/GPU   : {ok_sv}")
        print(f"tensor_network/GPU: {ok_tn}")

    # Pass if statevector passed and tensor_network either passed or was skipped.
    ok = (ok_sv is True) and (ok_tn in (True, None))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
