# HCP Pipelines ICAFIX subdirectory.

This directory contains [HCP] and [Washington University] official versions
of scripts related to [FSL] [FIX].

See Examples/Scripts/IcaFixProcessingBatch.sh for an example launching
script.

Note that `FSL_FIXDIR` should be set to the standard [FIX]
installation. You may need to modify your FIX installation to fit your
environment. In particular, the ${FSL_FIXDIR}/settings.sh file may
need modification.  (The settings.sh.WUSTL_CHPC2 file in this
directory is the settings.sh file that is used on the WUSTL "CHPC2"
cluster).

<!-- References -->

[HCP]: http://www.humanconnectome.org
[Washington University]: http://www.wustl.edu
[FSL]: http://fsl.fmrib.ox.ac.uk/fsl/fslwiki
[FIX]: http://fsl.fmrib.ox.ac.uk/fsl/fslwiki/FIX
