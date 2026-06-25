#!/bin/bash
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --time=5:00:00
#SBATCH --account=matt_glasser
#SBATCH --partition=tier2_gpu
#SBATCH --gres=gpu:1
#SBATCH --mem=300G
#SBATCH --cpus-per-gpu=8
#SBATCH -x gpua401,gpua804,gpu04 

module load cuda
module load fsl/6.0.5

source activate /home/alexander.z/miniconda3/envs/mmorf
export FSLOUTPUTTYPE=NIFTI_GZ
