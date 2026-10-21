# Time-course analysis

The time-course report uses the normalized protein-level abundances saved by
the main MSstats report. It does not reread or reprocess the PSM file.

The one-command wrapper can run both stages and create the time-course
configuration automatically:

```bash
./pdtomsstats run \
  --config config/local-project.yml \
  --outputs html,timecourse \
  --protein-workbook data/my-project/proteins.xlsx \
  --time-column TimePoint \
  --group-column Infection \
  --reference-group Control \
  --comparison-group LGTV
```

See the [one-command guide](command.md) for Windows syntax and additional
options.

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
protein_workbook: "data/my-project/proteins.xlsx"
```

`protein_workbook` is optional for the statistical models. When supplied in
the YAML or with `--protein-workbook`, the trajectory dashboard parses the
`GN=` field from each Proteome Discoverer protein description. The selected-
protein dashboard card and protein-level HTML and CSV tables display the gene
symbol beside the protein accession. Semicolon-separated protein groups show
their unique symbols separated by `/`; proteins without a `GN=` value show
`NA`.

`time_unit` rescales time before trajectory fitting. Affine time rescaling does
not change the fitted orthogonal-polynomial or natural-spline model space.

## Statistical steps

1. Require at least `min_replicates_per_cell` finite protein values in every
   group-time cell.
2. Remove proteins with no variation.
3. Fit maSigPro with an orthogonal polynomial time basis and the reference
   group as baseline.
4. Control the maSigPro overall-model false-discovery rate, apply backward
   interaction-term selection, and require the configured minimum R-squared.
5. Fit a limma natural-spline model and jointly test all group-by-time spline
   coefficients with an empirical-Bayes moderated F test.
6. Control the limma interaction false-discovery rate with
   `limma_interaction_fdr`.
7. Export the union of significant proteins with statistics and coefficients
   from both models plus a `SignificanceCategory` value of `Both methods`,
   `maSigPro only`, or `limma-spline only`.
8. Average replicates and calculate comparison-minus-reference effects
   separately for the maSigPro and limma-spline protein sets.
9. Run Mfuzz independently for each set, including independent fuzzifier,
   Dmin, cselection, cluster-count, membership, and core-member results.
10. Export both model tables, the combined table, both Mfuzz result families,
    plots, saved objects, and session information.

## Principal outputs

- `timecourse_combined_significant_proteins.csv`: union of significant
  proteins, both models' statistics and coefficients, and the
  `SignificanceCategory` method-agreement label. Protein-level output tables
  include the workbook-derived `GeneSymbol` column when available.
- `masigpro_model_results.csv` and `limma_spline_model_results.csv`: complete
  model-specific results for all tested proteins.
- `mfuzz_method_parameter_comparison.csv`: side-by-side input counts,
  fuzzifiers, candidate and selected cluster counts, core-member counts, and
  clustering backend.
- `masigpro_mfuzz_*` and `limma_spline_mfuzz_*`: separate memberships,
  centroids, cluster summaries, and cluster-number diagnostics.
- `<request>.html`: self-contained interactive report with searchable,
  downloadable DT tables and plots for both methods. The primary HTML result
  table is a compact biological interpretation view with method agreement,
  adjusted p-values, maSigPro R-squared, separate method-specific Mfuzz
  clusters and memberships, and an early-to-late observed-effect summary; the
  complete coefficient-level results remain in the CSV files. An embedded
  client-side dashboard near the end of the report can search and select any
  significant protein, show its workbook-derived gene symbol, summarize its
  two-model and Mfuzz results in cards, and plot its raw biological replicates,
  group means, and standard errors. It uses
  ordinary in-document JavaScript and SVG so it works when the standalone HTML
  is opened directly from disk without a server.

## Important settings

| Setting | Purpose |
|---|---|
| `min_replicates_per_cell` | Balanced coverage required in every cell |
| `polynomial_degree` | Orthogonal-polynomial degree used by maSigPro |
| `spline_df` | Natural-spline time degrees of freedom used by limma |
| `model_fdr` | BH threshold for the maSigPro overall model |
| `limma_interaction_fdr` | BH threshold for the joint limma spline-interaction test |
| `coefficient_alpha` | Backward-selection threshold |
| `min_r_squared` | Minimum retained model fit |
| `min_clusters`, `max_clusters` | Mfuzz candidate cluster range |
| `core_membership` | Descriptive threshold for a core cluster member |

## Common stopping conditions

- Repeated `BioReplicate` identifiers: the design appears to be repeated
  measures.
- Too few samples in a group-time cell: lower the coverage requirement only
  with a documented scientific reason.
- No time-by-group proteins for either method: the configured criteria found no
  method-specific input for its Mfuzz run.
- Too few selected proteins for multiple cluster counts: broaden the cluster
  range or reconsider whether clustering is informative for that dataset.
