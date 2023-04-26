# HCP Pipelines MSMAll subdirectory

MSMAll is a tool for surface-based functional alignment. It uses T1w/T2w myelin maps, resting state network maps, and resting-state-based visuotopic maps to align a subject's cortical data to a group template. MSMAll should be run on sICA+FIX cleaned data (single run or multi-run). First run the MSMAll Pipeline to generate the MSMAll registration, then the DeDriftAndResample Pipeline. For historical reasons, MSMAll has a precomputed dedrifting that should be applied after the registration, which is where the name DeDriftAndResample comes from. Users should not compute new dedrifting spheres, except in the rare case that they are generating a new registration template (for non-human primates, or other circumstances where the existing HCP MSMAll template is not suitable), in which case the MSMRemoveGroupDrift script may be helpful.

# Notes on MATLAB usage

Several of the downstream scripts called by MSMAllPipeline.sh rely on
functions written in MATLAB. This MATLAB code can be executed in 3
possible modes, controlled by the `--matlab-run-mode` input argument:

0. Compiled Matlab -- more on this below
1. Interpreted Matlab (default) -- probably easiest to use, if it is an option for you
2. Interpreted Octave -- an alternative to Matlab

### Support for compiled MATLAB

If using Compiled Matlab, the `MATLAB_COMPILER_RUNTIME` environment variable
must be set to the directory containing the "MATLAB Compiler Runtime" (MCR)
version (installed on your system) that was used for the compilation, which
was 'R2017b/v93'.

i.e.,

```
export MATLAB_COMPILER_RUNTIME=/export/matlab/MCR/R2017b/v93
```

