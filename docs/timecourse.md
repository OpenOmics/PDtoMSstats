# Time-course analysis

The time-course report uses the normalized protein-level abundances saved by
the main MSstats report. It does not reread or reprocess the PSM file.

## Appropriate design

The current model is for independent samples. Every `BioReplicate` identifier
must occur only once among the included runs. Do not use this report for
repeated samples from the same subject without changing the statistical model.

The annotation saved by the main report must contain:

- a numeric time column;
- a group column containing the configured reference and comparison groups;
- unique `BioReplicate` identifiers;
- enough replicates in every group-time cell.

## Configure

Copy `config/timecourse-example.yml` and set:

```yaml
analysis_file: "results/my-project/msstats_workbook_export_objects.rds"
time_column: "Time"
group_column: "Group"
reference_group: "Reference"
comparison_group: "Treatment"
```

`time_unit` rescales time before polynomial fitting. It changes coefficient
units and numerical stability, not the fitted trajectories.

## Statistical steps

1. Require at least `min_replicates_per_cell` finite protein values in every
   group-time cell.
2. Remove proteins with no variation.
3. Fit a maSigPro polynomial regression with the reference group as baseline.
4. Control the overall-model false-discovery rate with Benjamini–Hochberg.
5. Apply backward coefficient selection and the configured minimum R-squared.
6. Select proteins with at least one comparison-group-by-time term. A constant
   difference between groups is not a progression difference.
7. Average replicates, calculate comparison-minus-reference effects, and
   standardize each selected trajectory.
8. Choose an Mfuzz cluster count from the configured range using Dmin and
   repeated non-empty-cluster diagnostics.
9. Export all memberships, centroids, unstandardized effects, model results,
   diagnostics, plots, and session information.

## Important settings

| Setting | Purpose |
|---|---|
| `min_replicates_per_cell` | Balanced coverage required in every cell |
| `polynomial_degree` | Maximum trajectory curvature modeled by maSigPro |
| `model_fdr` | BH threshold for overall models |
| `coefficient_alpha` | Backward-selection threshold |
| `min_r_squared` | Minimum retained model fit |
| `min_clusters`, `max_clusters` | Mfuzz candidate cluster range |
| `core_membership` | Descriptive threshold for a core cluster member |

## Common stopping conditions

- Repeated `BioReplicate` identifiers: the design appears to be repeated
  measures.
- Too few samples in a group-time cell: lower the coverage requirement only
  with a documented scientific reason.
- No time-by-group proteins: the configured criteria found no differential
  progression, so Mfuzz has no statistically selected input to cluster.
- Too few selected proteins for multiple cluster counts: broaden the cluster
  range or reconsider whether clustering is informative for that dataset.
