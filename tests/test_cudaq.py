#!/usr/bin/env python3
"""
CUDA-Q (cudaq) sanity test:
- target selection (CUDAQ_TARGET env; default 'nvidia', fallback 'qpp')
- Bell state sampling (~50/50 00 and 11)
- observe() on ZZ (~ +1)
Exit code: 0 on success; 1 otherwise.
"""

import os
import sys
import math

try:
    import cudaq
except Exception as e:
    print("ERROR: Failed to import cudaq:", repr(e))
    sys.exit(1)

def banner(msg):
    print("\n" + "=" * 60)
    print(msg)
    print("=" * 60)

def set_target():
    target = os.environ.get("CUDAQ_TARGET", "nvidia")
    try:
        cudaq.set_target(target)
        print(f"Target set to: {target}")
        return target
    except Exception as e:
        print(f"WARNING: set_target('{target}') failed: {e!r}")
        # try CPU reference backend
        try:
            cudaq.set_target("qpp")
            print("Falling back to: qpp")
            return "qpp"
        except Exception as e2:
            print("ERROR: Could not set any target:", repr(e2))
            sys.exit(1)

# --- Define a tiny kernel that makes a Bell state
@cudaq.kernel
def bell():
    q = cudaq.qvector(2)
    cudaq.h(q[0])
    cudaq.cx(q[0], q[1])  # entangle

def test_sample(shots=4096, tol=0.20):
    """Sample the Bell kernel; expect roughly 50/50 00 and 11."""
    banner("Test 1: sample() Bell state")
    res = cudaq.sample(bell, shots_count=shots)
    # res.counts is a dict like {'00': n, '11': m}
    counts = dict(res.counts) if hasattr(res, "counts") else dict(res)
    print("Counts:", counts)
    z = counts.get("00", 0)
    o = counts.get("11", 0)
    total = sum(counts.values())
    ok = (total == shots) and abs(z - o) <= tol * shots and (z + o) >= 0.95 * shots
    print(f"00={z}, 11={o}, shots={shots}, OK={ok}")
    return ok

def test_observe():
    """Check <ZZ> on the Bell state (~ +1)."""
    from cudaq import spin
    banner("Test 2: observe() on ZZ")
    H = spin.z(0) * spin.z(1)
    exp_val = cudaq.observe(bell, H)
    print(f"<ZZ> = {exp_val}")
    ok = abs(exp_val - 1.0) < 5e-3  # loose tolerance
    print("OK:", ok)
    return ok

def main():
    print("cudaq version:", getattr(cudaq, "__version__", "unknown"))
    tgt = set_target()

    ok1 = False
    ok2 = False
    try:
        ok1 = test_sample()
    except Exception as e:
        print("sample() test failed:", repr(e))

    try:
        ok2 = test_observe()
    except Exception as e:
        print("observe() test failed:", repr(e))

    banner("Summary")
    print(f"Target: {tgt}")
    print(f"sample(): {ok1}")
    print(f"observe(): {ok2}")

    sys.exit(0 if (ok1 and ok2) else 1)

if __name__ == "__main__":
    main()

