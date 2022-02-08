# Temporal ICA, beta version

This pipeline uses [temporal ICA][tICA] on a large amount of fMRI data (typically a large group of subjects),
in order to separate global nuisance effects (such as due to respiration) from neural signals that
have a nonzero spatial mean.  Some features are currently incomplete.

The processing modes also allow for applying temporal ICA cleanup to datasets that are not
large enough to reliably produce a new temporal ICA decomposition.  Briefly, the processing
modes are:

- NEW - do a full pipeline run from scratch, starting with a fresh group-PCA (using [MIGP]), intended for large datasets
- REUSE_SICA_ONLY - use a previous group-PCA result, but estimate the temporal ICA from scratch ([ICASSO] with random seeds)
- INITIALIZE_TICA - use a previous group-PCA result, and estimate temporal ICA starting from a previous
tICA mixing matrix, but allow it to change to fit the new data (ICASSO starting from prior result)
- REUSE_TICA - use a previous group-PCA and tICA mixing matrix (and signal/nuisance classification),
intended for small datasets

Automated classification of tICA components into signal versus nuisance is not yet integrated.

<!-- References -->
[MIGP]: https://www.sciencedirect.com/science/article/pii/S105381191400634X
[ICASSO]: https://research.ics.aalto.fi/ica/icasso/documentation.shtml
[tICA]: https://www.sciencedirect.com/science/article/abs/pii/S1053811918303963
