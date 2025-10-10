#!/bin/bash --login
#SBATCH --account=pawsey0001
#SBATCH --partition=gpu
#SBATCH --time=12:00:00
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=64
#SBATCH --ntasks=1
#SBATCH --job-name=spack_install
#SBATCH --exclusive
#SBATCH --mem=0
#SBATCH --exclude=ella-n006,ella-n007

#module purge
module unload pawseyenv
. settings.sh
module list

export MODULEPATH=/opt/nvidia/hpc_sdk/modulefiles:$MODULE_PREFIX:/software/hpcx/2.20/modulefiles:$MODULEPATH

srun -N 1 -n 1 -c 64 bash scripts/install_software_stack.sh
