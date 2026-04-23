#!/usr/bin/env python3
"""
PyTorch sanity test.

Single-rank mode: import / CUDA device / matmul / autograd / NCCL + cuDNN presence.
MPI mode (size > 1): init torch.distributed with NCCL, bootstrap RANK/WORLD_SIZE
and MASTER_ADDR via mpi4py, then all_reduce a rank-indexed tensor.
"""
import os
import socket
import sys


def banner(msg):
    print("\n" + "=" * 60)
    print(msg)
    print("=" * 60, flush=True)


def detect_mpi():
    try:
        from mpi4py import MPI  # type: ignore
    except ImportError:
        return 0, 1, None
    comm = MPI.COMM_WORLD
    return comm.Get_rank(), comm.Get_size(), comm


def single_rank(torch):
    banner(f"PyTorch {torch.__version__}")
    print("Compiled with CUDA: ", torch.version.cuda)
    print("CUDA available    : ", torch.cuda.is_available())
    print("CUDA device count : ", torch.cuda.device_count())
    print("NCCL available    : ", torch.distributed.is_nccl_available())
    print("cuDNN available   : ", torch.backends.cudnn.is_available())
    if torch.backends.cudnn.is_available():
        print("cuDNN version     : ", torch.backends.cudnn.version())

    if not torch.cuda.is_available():
        print("CUDA not available — test cannot exercise GPU.")
        return False

    print("CUDA device name  : ", torch.cuda.get_device_name(0))
    cc = torch.cuda.get_device_capability(0)
    print(f"Compute capability: {cc[0]}.{cc[1]}")

    banner("Matmul on GPU (fp32, 512x512)")
    torch.manual_seed(0)
    A = torch.randn(512, 512, device="cuda", dtype=torch.float32)
    B = torch.randn(512, 512, device="cuda", dtype=torch.float32)
    C_gpu = A @ B
    C_ref = A.cpu() @ B.cpu()
    diff = (C_gpu.cpu() - C_ref).abs().max().item()
    print(f"max|C_gpu - C_cpu| = {diff:.3e}")
    ok_mm = diff < 1e-3

    banner("Autograd on GPU: d/dx sum(2x) == 2")
    x = torch.randn(256, device="cuda", requires_grad=True)
    y = (x * 2).sum()
    y.backward()
    ok_grad = torch.allclose(x.grad, torch.full_like(x.grad, 2.0))
    print("gradient check:", ok_grad)

    # cuDNN smoke test: 2D conv forward + backward.
    banner("cuDNN conv2d forward/backward")
    if torch.backends.cudnn.is_available():
        torch.backends.cudnn.enabled = True
        inp = torch.randn(4, 3, 32, 32, device="cuda", requires_grad=True)
        conv = torch.nn.Conv2d(3, 8, kernel_size=3, padding=1).cuda()
        out = conv(inp)
        out.sum().backward()
        ok_cudnn = inp.grad is not None and torch.isfinite(inp.grad).all().item()
        print(f"conv2d output shape={tuple(out.shape)}, grad finite={ok_cudnn}")
    else:
        ok_cudnn = None
        print("cuDNN disabled at build time; skipping conv2d check.")

    banner("Summary")
    print(f"matmul    : {ok_mm}")
    print(f"autograd  : {ok_grad}")
    print(f"cudnn     : {ok_cudnn}")
    return ok_mm and ok_grad and (ok_cudnn in (True, None))


def mpi_distributed(torch, rank, size, comm):
    banner(f"torch.distributed all_reduce (NCCL, rank {rank}/{size})")
    import torch.distributed as dist

    # Bootstrap MASTER_ADDR/PORT via MPI rank-0 hostname broadcast, so torch's
    # TCP init_process_group finds a rendezvous without torchrun.
    hostname = socket.gethostname() if rank == 0 else None
    master_addr = comm.bcast(hostname, root=0)

    os.environ["MASTER_ADDR"] = master_addr
    os.environ["MASTER_PORT"] = os.environ.get("MASTER_PORT", "29500")
    os.environ["RANK"] = str(rank)
    os.environ["WORLD_SIZE"] = str(size)
    os.environ["LOCAL_RANK"] = "0"

    # One GH200 per node -> device 0 on each rank.
    torch.cuda.set_device(0)

    dist.init_process_group(backend="nccl")
    t = torch.tensor([float(rank + 1)], device="cuda")
    dist.all_reduce(t, op=dist.ReduceOp.SUM)
    got = t.item()
    expected = sum(range(1, size + 1))
    ok = abs(got - expected) < 1e-6
    if rank == 0:
        print(f"all_reduce sum of ranks+1: got={got} expected={expected} OK={ok}")
    dist.destroy_process_group()
    return ok


def main():
    try:
        import torch
    except Exception as e:
        print("ERROR: failed to import torch:", repr(e))
        return 1

    rank, size, comm = detect_mpi()
    if size > 1:
        ok = mpi_distributed(torch, rank, size, comm)
        return 0 if ok else 1
    ok = single_rank(torch)
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
