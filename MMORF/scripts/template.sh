#!/bin/bash
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --time=5:00:00
#SBATCH --account=XXX
#SBATCH --partition=XXX
#SBATCH --gres=gpu:1
#SBATCH --mem=300G
#SBATCH --cpus-per-gpu=8

module load cuda
module load fsl/6.0.5

source activate XXX/miniconda3/envs/mmorf
export FSLOUTPUTTYPE=NIFTI_GZ
