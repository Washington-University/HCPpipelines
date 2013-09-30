#!/bin/bash

workingdir=$1
InputDotFile=${workingdir}/merged_matrix2.dot
Nparts=30
NGPUs=2

# Give the job a name
echo "#!/bin/bash"  > ${workingdir}/Mat2GPUSub.sh
echo "#PBS -N Mat2_GPU" >> ${workingdir}/Mat2GPUSub.sh

# Submit to the SMP nodes
echo "#PBS -q dque_gpu" >> ${workingdir}/Mat2GPUSub.sh

# Ask for GPUs
echo "#PBS -l nodes=1:ppn=${NGPUs}:gpus=${NGPUs},walltime=8:00:00,vmem=64gb" >> ${workingdir}/Mat2GPUSub.sh

Mode=1 # Mode 0 for Sparse, Mode 1 for Full
echo "${HCPPIPEDIR_Bin}/mult_M_transM_new ${InputDotFile} ${workingdir}/Conn2.data $Nparts ${Mode} ${NGPUs} ${workingdir}/Mat2_logs/GPUtest.log" >> ${workingdir}/Mat2GPUSub.sh

chmod +x ${workingdir}/Mat2GPUSub.sh