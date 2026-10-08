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
3. Adds raw and normalized peptide and protein abundances to the hierarchical
   workbook.
4. Adds condition means and comparison statistics.
5. Adds an `All MSstats Results` worksheet containing every protein–contrast
   result, including identifiers that do not exactly match a source master row.
6. Creates comparison-specific DE and GSEA worksheets.
7. Adds a `Contrast Guide` worksheet when the report saved contrast metadata.
8. Creates an in-workbook data dictionary.

The contrast guide contains the coefficient formula, what each comparison
measures, how to interpret positive and negative estimates, what a
non-significant result means, and the main limitation of the test. The same
information is available in `msstats_contrast_guide.csv` in the results
directory.

## Formatting

The main worksheet uses a consistent hierarchy:

- Blue rows for proteins.
- Warm rows for peptide headers and peptide details, including empty cells to
  the right of peptide-level measurements.
- Scientific notation for abundance and probability fields where appropriate.
- Fixed widths for the first metadata columns.
- Frozen row 1 and columns A through D.

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
