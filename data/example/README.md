# De-identified demonstration data

This directory contains a compact subset of a Proteome Discoverer PSM export
and its independent-sample annotation. It exists only to test and demonstrate
the software.

De-identification applied to the public copy:

- project, request, acquisition, and sample names were removed;
- run identifiers were replaced with `RUN001`, `RUN002`, and so on;
- sample names and biological-replicate identifiers were replaced with generic
  sequential identifiers;
- source group names were replaced with `Reference` and `Treatment`;
- protein accessions and peptide sequences were replaced with synthetic IDs;
- only a small set of proteins and the columns needed by the workflow were
  retained;
- duplicate PSM measurements of the same protein/peptide/charge/run feature
  were reduced to the maximum quantitative value, matching the report's MSstats
  duplicate-row rule.

The subset includes proteins chosen to exercise the time-course code and is
therefore enriched for temporal signal. It is **not** an unbiased biological
sample and must not be used for scientific conclusions, benchmarking effect
rates, or publication.

Files:

- `psm.csv`: de-identified PSM-level input.
- `annotation.csv`: 60 independent samples spanning two groups, six time
  points, and five replicates per group-time cell.
- `contrasts.tsv`: six time-matched Treatment-versus-Reference comparisons.
- `SHA256SUMS`: checksums for integrity verification.

The maintainer utility `scripts/create_example_subset.R` records the mechanical
subsetting and pseudonymization procedure. It is not used during normal
analysis.
