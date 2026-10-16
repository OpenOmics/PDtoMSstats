# Formatted workbook export

The optional workbook exporter combines the saved analysis results with a
hierarchical Proteome Discoverer protein workbook.

## Run the export

First render the report. Then run:

```bash
Rscript scripts/export_workbook.R \
  data/my-project-protein.xlsx \
  results/my-project
```

An explicit output filename can be supplied as a third argument:

```bash
Rscript scripts/export_workbook.R \
  data/my-project-protein.xlsx \
  results/my-project \
  results/my-project/my-project-protein-MSstats.xlsx
```

The wrapper:

1. Reads `msstats_workbook_export_objects.rds` from the results directory.
2. Calculates unnormalized, non-imputed protein abundances with the report's
   saved summarization settings.
3. Renames the complete hierarchical worksheet to `Peptide` and creates a
   `Proteins` worksheet containing only master proteins and master-protein
   candidates.
4. Adds raw and normalized peptide and protein abundances to both applicable
   views.
5. Adds condition means and comparison statistics.
6. Adds an `All MSstats Results` worksheet containing every protein–contrast
   result, including identifiers that do not exactly match a source master row.
7. Creates comparison-specific DE and GSEA worksheets.
8. Adds a `Contrast Guide` worksheet when the report saved contrast metadata.
9. Creates an in-workbook data dictionary.

The contrast guide contains the coefficient formula, what each comparison
measures, how to interpret positive and negative estimates, what a
non-significant result means, and the main limitation of the test. The same
information is available in `msstats_contrast_guide.csv` in the results
directory.

By default, DE worksheets use the report's volcano thresholds (adjusted
p-value below `0.05` and absolute log2 fold change of at least `1`). Set
`differential_pvalue_cutoff` and `differential_log2fc_cutoff` in YAML, or use
the wrapper flags `--de-pvalue-cutoff` and `--de-log2fc-cutoff`, to change the
Excel filters without changing the volcano plots.

Set `maximum_allowed_fold_change: 100` in the main YAML configuration, or use
`--maximum-allowed-fold-change 100` with `pdtomsstats run`, to control the
exported MSstats Ratio and log2FC in the `Proteins` and `Peptide` views. The
default is 100: ratios are bounded by 0.01 and 100 and log2FC by approximately
-6.643856 and +6.643856. Infinite estimates and finite estimates beyond the
limits are capped; missing estimates remain missing. The limit must be finite
and at least 1. These are reporting bounds, not measured fold changes.

The cap does not alter the model, p-values, CSV/RDS results, `All MSstats
Results`, or DE-sheet estimates and selection. Those retain the original
model results. Original PD columns are preserved. The workbook export guide
records the selected cap. Older saved analysis objects without this setting
use 100; `export_msstats_workbook()` also accepts a named
`maximum_allowed_fold_change` override when re-exporting saved results.

## Formatting

The workbook uses a consistent hierarchy:

- Blue rows for master proteins and master-protein candidates across the full
  worksheet width, including cells without values.
- Warm rows for peptide headers and peptide details across the full worksheet
  width, including cells without values.
- Scientific notation for abundance and probability fields where appropriate.
- Fixed widths for the first metadata columns.
- Frozen row 1 and columns A through D on both `Proteins` and `Peptide`.
- Protein rows sorted by descending signed MSstats log2FC for a single
  comparison; for multiple comparisons, by descending source PSM count.
  Missing sort values are last and ties keep source order. If no PSM count
  column exists, source order is retained with a warning.
- The peptide-only `Positions in Proteins`, `Quan Usage`, and
  `Quan Ratio Usage` columns are placed at the far right of both hierarchy
  views. Their values remain on peptide rows, while the corresponding empty
  protein cells no longer interrupt the metadata and MSstats result columns.
- Blue–white–red gradients on the `Proteins` log2FC columns, centered at zero
  with symmetric endpoints of `-/+ log2(maximum_allowed_fold_change)`.
- Non-finite statistical values written as `NA`, `Inf`, or `-Inf`, rather than
  Excel numeric-error cells.

The `Proteins` worksheet is the compact result view. The `Peptide` worksheet
retains the original Proteome Discoverer hierarchy and its collapsed peptide
sections.

## Proteome Discoverer compatibility

Some Proteome Discoverer workbooks contain nonstandard Excel relationship
identifiers or omit standard cell coordinates that `openxlsx` cannot read.
The exporter checks for both problems before modifying the workbook.

Normal workbooks require only the R packages listed by
`scripts/install_dependencies.R`. When compatibility conversion is needed, the
exporter automatically uses the R package `openxlsx2` to create a temporary
standards-compliant copy. The converted copy is deleted after the export, and
the original workbook is never changed. If conversion fails, the exporter
stops with instructions to open the protein workbook in Excel or LibreOffice
and save it as a new `.xlsx` file.
