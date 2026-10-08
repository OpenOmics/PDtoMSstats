# Example walkthrough

The tracked example verifies that the complete workflow can start with a PSM
table and finish with MSstats, maSigPro, and Mfuzz outputs.

## Design

- two independent-sample groups: `Reference` and `Treatment`;
- six times: 12, 24, 48, 72, 96, and 120;
- five unique biological replicates per group-time cell;
- 60 runs and 100 synthetic protein identifiers;
- six time-matched Treatment-versus-Reference contrasts.

The subset was selected to retain temporal patterns, so it is useful for
software testing but biased for biology. All project/sample labels, accessions,
and peptide sequences are synthetic. See `data/example/README.md` for the full
de-identification description.

## Verify file integrity

Linux:

```bash
cd data/example
sha256sum -c SHA256SUMS
```

macOS:

```bash
cd data/example
shasum -a 256 -c SHA256SUMS
```

## Run both stages

```bash
docker compose run --rm pdtomsstats \
  Rscript scripts/run_pipeline.R \
  config/example-data.yml \
  config/example-data-timecourse.yml
```

The main outputs include:

- `results/example/deidentified-example.html`;
- `results/example/msstats_all_group_comparisons.csv`;
- one CSV for each planned comparison;
- `results/example/msstats_workbook_export_objects.rds`.

The time-course outputs include:

- `results/example/timecourse/deidentified-example-timecourse.html`;
- `masigpro_model_results.csv`;
- `masigpro_significant_proteins_by_variable.csv`;
- `mfuzz_cluster_membership.csv`;
- `mfuzz_cluster_centroids.csv`;
- `timecourse_group_difference_effects.csv`;
- a serialized RDS containing the complete time-course objects.

The example deliberately sets `run_gsea: false` because synthetic protein IDs
must not be presented as organism identifiers.
