#!/usr/bin/env python3
"""
CUDA-Q (cudaq) sanity test.

1. Introspection — version, get_targets, set_target switch
2. Kernel execution — @cudaq.kernel + cudaq.sample on qpp-cpu backend

Exit code: 0 on success; 1 otherwise.
"""

import sys

try:
    import cudaq
except Exception as e:
    print("ERROR: Failed to import cudaq:", repr(e))
    sys.exit(1)


def banner(msg):
    print("\n" + "=" * 60)
    print(msg)
    print("=" * 60)


def smoke_introspection():
    banner("CUDA-Q introspection")
    print("cudaq version:", getattr(cudaq, "__version__", "unknown"))
    tgts = [t.name for t in cudaq.get_targets()]
    print("available targets (first 10):", tgts[:10])
    print("current target:", cudaq.get_target().name)

    # Target switching is part of the Python bindings' public API.
    for t in ("nvidia", "qpp-cpu"):
        try:
            cudaq.set_target(t)
            print(f"set_target('{t}') OK -> current:", cudaq.get_target().name)
        except Exception as e:
            print(f"set_target('{t}') failed: {e!r}")
            return False
    return True


def kernel_exec():
    banner("Kernel execution (@kernel + sample)")
    cudaq.set_target("qpp-cpu")

    @cudaq.kernel
    def bell():
        q = cudaq.qvector(2)
        h(q[0])
        x.ctrl(q[0], q[1])

    res = cudaq.sample(bell, shots_count=1000)
    counts = dict(res)
    print("counts:", counts)
    zeros = counts.get("00", 0)
    ones = counts.get("11", 0)
    ok = (zeros + ones) >= 950 and abs(zeros - ones) <= 200
    print("OK:", ok)
    return ok


def main():
    ok_intro = smoke_introspection()

    ok_kernel = False
    try:
        ok_kernel = kernel_exec()
    except Exception as e:
        print("kernel_exec failed:", repr(e))
        ok_kernel = False

    banner("Summary")
    print(f"introspection: {ok_intro}")
    print(f"kernel exec  : {ok_kernel}")

    sys.exit(0 if (ok_intro and ok_kernel) else 1)


if __name__ == "__main__":
    main()
