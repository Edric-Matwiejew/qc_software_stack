#!/usr/bin/env python3
import os, sys, math
import cupy as cp
import numpy as np

def fail(msg, code=1):
    print("ERROR:", msg)
    sys.exit(code)

def main():
    # --- Environment/version sanity ---
    expected = os.environ.get("CUPY_VERSION")  # your module can export this
    actual = cp.__version__
    print("CuPy version:", actual)
    print("CUDA runtime version:", cp.cuda.runtime.runtimeGetVersion())
    print("Number of GPUs:", cp.cuda.runtime.getDeviceCount())

    if expected and not actual.startswith(expected):
        fail(f"Loaded CuPy ({actual}) != expected ({expected})", code=2)

    # --- Elementwise test (exact small) ---
    x_small = cp.arange(16, dtype=cp.float32)
    y_small = cp.arange(16, dtype=cp.float32)
    z_small = x_small * y_small + 2.5
    ref_small = (np.arange(16, dtype=np.float32) * np.arange(16, dtype=np.float32) + 2.5)
    if not np.allclose(z_small.get().astype(np.float64), ref_small.astype(np.float64), atol=0, rtol=0):
        fail("Small elementwise test mismatch")

    # --- Large test with float64 reduction to avoid precision trap ---
    N = 10**6
    x = cp.arange(N, dtype=cp.float32)
    y = cp.arange(N, dtype=cp.float32)
    z = x * y + 2.5

    # Force high-precision reduction on both sides
    mean_gpu = z.mean(dtype=cp.float64).get()
    ref = (np.arange(N, dtype=np.float64) * np.arange(N, dtype=np.float64) + 2.5).mean()

    diff = abs(mean_gpu - ref)
    print("Mean(z) GPU (float64 reduce):", mean_gpu)
    print("Mean(z) CPU (float64 reduce):", ref)
    print("Abs diff:", diff)
    if not math.isfinite(diff) or diff > 1e-6 * abs(ref):
        fail("Mean mismatch beyond tolerance")

    # --- cuBLAS smoke test ---
    a = cp.random.rand(512, 512, dtype=cp.float32)
    b = cp.random.rand(512, 512, dtype=cp.float32)
    c = a @ b
    print("Matmul OK. Shape:", c.shape)

    print("All CuPy tests passed.")
    return 0

if __name__ == "__main__":
    sys.exit(main())

