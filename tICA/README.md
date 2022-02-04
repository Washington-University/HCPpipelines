# Temporal ICA

This pipeline uses ICA on a large amount of fMRI data (typically a large group of subjects),
in order to separate global nuisance effects (such as due to respiration) from neural signals that
have a nonzero spatial mean.

The processing modes also allow for applying temporal ICA cleanup to datasets that are not
large enough to reliably produce a new temporal ICA decomposition.  Briefly, the processing
modes are:

- NEW - do a full pipeline run from scratch, starting with a fresh MIGP, intended for large datasets

- REUSE_SICA_ONLY - use a previous MIGP result, but estimate the temporal ICA from scratch

- INITIALIZE_TICA - use a previous MIGP result, and estimate temporal ICA starting from a previous
tICA mixing matrix, but allow it to change to fit the new data

- REUSE_TICA - use a previous MIGP and tICA mixing matrix (and signal/nuisance classification),
intended for small datasets
