#!/usr/bin/env python3
"""
qiskit-aer 0.17.1 + cuQuantum sanity test

- Uses an instance to call available_methods()/available_devices()
- Tests cuStateVec on GPU (if available)
- Optionally tests tensor_network on GPU (if available)
"""

from qiskit import QuantumCircuit
from qiskit import ClassicalRegister
from qiskit_aer import AerSimulator
import math
import sys

def banner(msg):
    print("\n" + "=" * 60)
    print(msg)
    print("=" * 60)

def make_ghz(n): 
    qc = QuantumCircuit(n, n) 
    qc.h(0) 
    for i in range(n - 1): 
        qc.cx(i, i + 1) 
        qc.barrier() 
        qc.measure_all() 
    return qc

def check_ghz_counts(counts, n, shots, tol=0.15):
    def norm(k):
        k = k.replace(" ", "")  # collapse multiple cregs
        return k[-n:]           # take the last n bits (safety)
    z = "0" * n
    o = "1" * n
    c0 = sum(v for k, v in counts.items() if norm(k) == z)
    c1 = sum(v for k, v in counts.items() if norm(k) == o)
    ok = (c0 + c1) == shots and abs(c0 - c1) <= tol * shots
    return ok, c0, c1

def probe_capabilities():
    probe = AerSimulator()  # CPU default
    methods = set(probe.available_methods())
    devices = set(probe.available_devices())
    print("Available methods:", sorted(methods))
    print("Available devices:", sorted(devices))
    return methods, devices

def run_statevector_gpu(n=16, shots=2048):
    banner("Test 1: cuStateVec (statevector on GPU)")
    methods, devices = probe_capabilities()
    if "statevector" not in methods or "GPU" not in devices:
        print("Statevector/GPU not available in this build. Skipping.")
        return None

    # Build GPU statevector simulator; cuStateVec is used if Aer was compiled with it.
    sim = AerSimulator(
        method="statevector",
        device="GPU",
        precision="double",
        cuStateVec_enable=True,   # ignored if not compiled in
    )
    print("Simulator options:", sim.options)
    qc = make_ghz(n)
    result = sim.run(qc, shots=shots, seed_simulator=42).result()
    counts = result.get_counts()
    ok, c0, c1 = check_ghz_counts(counts, n, shots)
    print(f"Counts (sample): {dict(list(counts.items())[:4])}")
    print(f"Zeros={c0}, Ones={c1}, OK={ok}")
    return ok

def run_tensor_network_gpu(n=40, shots=1024):
    banner("Test 2: cuTensorNet (tensor_network on GPU)")
    methods, devices = probe_capabilities()
    if "tensor_network" not in methods or "GPU" not in devices:
        print("tensor_network/GPU not available in this build. Skipping.")
        return None

    sim = AerSimulator(method="tensor_network", device="GPU", precision="double")
    print("Simulator options:", sim.options)
    qc = make_ghz(n)
    result = sim.run(qc, shots=shots, seed_simulator=123).result()
    counts = result.get_counts()
    ok, c0, c1 = check_ghz_counts(counts, n, shots)
    print(f"Counts (sample): {dict(list(counts.items())[:4])}")
    print(f"Zeros={c0}, Ones={c1}, OK={ok}")
    return ok

def main():
    ok_sv = None
    ok_tn = None

    try:
        ok_sv = run_statevector_gpu()
    except Exception as e:
        print("Statevector GPU test failed:", repr(e))
        ok_sv = False

    try:
        ok_tn = run_tensor_network_gpu()
    except Exception as e:
        print("Tensor-network GPU test failed:", repr(e))
        ok_tn = False

    banner("Summary")
    print(f"cuStateVec(statevector/GPU): {ok_sv}")
    print(f"cuTensorNet(tensor_network/GPU): {ok_tn}")

    # Success if cuStateVec passed, and tensor_network either passed or was skipped.
    if ok_sv is True and (ok_tn in (True, None)):
        return 0
    return 1

if __name__ == "__main__":
    sys.exit(main())

