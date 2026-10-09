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

## Formatting

The workbook uses a consistent hierarchy:

- Blue rows for master proteins and master-protein candidates across the full
  worksheet width, including cells without values.
- Warm rows for peptide headers and peptide details across the full worksheet
  width, including cells without values.
- Scientific notation for abundance and probability fields where appropriate.
- Fixed widths for the first metadata columns.
- Frozen row 1 and columns A through D on both `Proteins` and `Peptide`.
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
