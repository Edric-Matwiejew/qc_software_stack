#!/usr/bin/env python3
"""
PennyLane Lightning sanity test.

Auto-detects which Lightning backend is installed (whichever `pennylane_lightning_*`
Python subpackage is importable) and whether the process is running under MPI
(via mpi4py's COMM_WORLD). Builds a small RY-then-CNOT-chain GHZ-like circuit,
measures <Z0>, and compares against the analytic value cos(theta).
"""
import sys

import pennylane as qml
from pennylane import numpy as np


def banner(msg):
    print("\n" + "=" * 60)
    print(msg)
    print("=" * 60)


def detect_device():
    """Find which Lightning backend is installed.

    `pennylane_lightning` is always present (the core qubit backend). Search
    for the installed GPU/Kokkos/Tensor extension — each variant installs its
    own `pennylane_lightning.lightning_X` subpackage.
    """
    import importlib
    for submod, dev_name in [
        ("pennylane_lightning.lightning_kokkos", "lightning.kokkos"),
        ("pennylane_lightning.lightning_gpu",    "lightning.gpu"),
        ("pennylane_lightning.lightning_tensor", "lightning.tensor"),
    ]:
        try:
            importlib.import_module(submod)
            return dev_name
        except ImportError:
            continue
    return "lightning.qubit"


def detect_mpi():
    """Return (rank, size) under MPI, else (0, 1)."""
    try:
        from mpi4py import MPI  # noqa: F401
        comm = MPI.COMM_WORLD
        return comm.Get_rank(), comm.Get_size()
    except ImportError:
        return 0, 1


def main():
    device_name = detect_device()
    rank, size = detect_mpi()
    mpi_mode = size > 1
    n_wires = 8

    banner(f"PennyLane-Lightning: device={device_name} wires={n_wires} "
           f"rank={rank}/{size} mpi={mpi_mode}")
    print(f"PennyLane version: {qml.__version__}")

    # lightning.gpu supports multi-GPU MPI via mpi=True.
    dev_kwargs = {"wires": n_wires}
    if mpi_mode and device_name == "lightning.gpu":
        dev_kwargs["mpi"] = True

    try:
        dev = qml.device(device_name, **dev_kwargs)
    except Exception as e:
        print(f"ERROR: could not construct device {device_name}: {e!r}")
        return 2

    print(f"Device: {dev}")

    @qml.qnode(dev)
    def circuit(theta):
        qml.RY(theta, wires=0)
        for w in range(n_wires - 1):
            qml.CNOT(wires=[w, w + 1])
        return qml.expval(qml.PauliZ(0))

    theta = 0.7
    try:
        measured = float(circuit(theta))
    except Exception as e:
        print(f"ERROR: circuit execution raised: {e!r}")
        return 3

    expected = float(np.cos(theta))
    diff = abs(measured - expected)

    # Only rank 0 prints + returns in MPI mode to keep output sane.
    if rank == 0:
        print(f"<Z0> measured: {measured:.9f}")
        print(f"<Z0> analytic: {expected:.9f}")
        print(f"|diff|:        {diff:.2e}")

    tol = 1e-5
    if diff > tol:
        if rank == 0:
            print(f"FAIL: deviation {diff:.2e} exceeds tol {tol:.0e}")
        return 1

    if rank == 0:
        print("PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
