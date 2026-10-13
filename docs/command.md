# Run PDtoMSstats with one command

The `pdtomsstats` wrapper collects the input choices, writes resolved YAML
files, validates the design, and runs the requested outputs. It uses the same
generalized analysis and workbook functions as the individual scripts.

## Interactive wizard

From the repository folder, start the wizard.

macOS or Linux:

```bash
./pdtomsstats
```

Windows PowerShell:

```powershell
.\pdtomsstats.ps1
```

The wizard asks for the PSM and annotation files, output types, project name,
condition design, and any information required by Excel or time-course output.
On its first run, the launcher downloads the public GHCR image. If the image
cannot be downloaded, it offers the existing local Docker build as a fallback.

If macOS or Linux reports that the launcher is not executable, run it through
the shell:

```bash
sh pdtomsstats
```

## Short command

Create only the standard HTML report:

```bash
./pdtomsstats run \
  --psm data/my-project/psm.xlsx \
  --annotation data/my-project/annotation.csv \
  --outputs html
```

On Windows, replace `./pdtomsstats` with `.\pdtomsstats.ps1` and place the
command on one line, or use PowerShell backticks for line continuation.

## Select outputs

The supported output names are `html`, `excel`, and `timecourse`. They can be
combined in any order:

```bash
./pdtomsstats run \
  --psm data/my-project/psm.xlsx \
  --annotation data/my-project/annotation.csv \
  --protein-workbook data/my-project/proteins.xlsx \
  --outputs html,excel
```

The full formatted Excel workbook requires the Proteome Discoverer protein
workbook. The core CSV and RDS analysis products are always saved because the
requested outputs depend on them.

### Set Excel differential-expression thresholds

Comparison-specific `DE ...` worksheets normally inherit the volcano-plot
cutoffs: adjusted p-value below `0.05` and absolute log2 fold change of at
least `1`. Override only the Excel filters with:

```bash
./pdtomsstats run \
  --config config/local-project.yml \
  --protein-workbook data/my-project/proteins.xlsx \
  --outputs html,excel \
  --de-pvalue-cutoff 0.5 \
  --de-log2fc-cutoff 0.25
```

The resolved values are recorded as `differential_pvalue_cutoff` and
`differential_log2fc_cutoff`. The p-value flag applies to the MSstats
Benjamini-Hochberg adjusted p-value.

### Set the GSEA result-table threshold

The GSEA result cutoff defaults to `0.05`. Override it independently with:

```bash
./pdtomsstats run \
  --config config/local-project.yml \
  --outputs html,excel \
  --gsea-pvalue-cutoff 0.5
```

GSEA uses the complete ranked protein list, so the Excel DE-sheet log2 fold-
change cutoff does not apply to GSEA. The resolved cutoff is recorded as
`gsea_pvalue_cutoff`.

## Construct Condition from annotation columns

If the annotation already contains `Condition`, no condition option is needed.
Otherwise, name the columns used to construct it:

```bash
./pdtomsstats run \
  --psm data/my-project/psm.xlsx \
  --annotation data/my-project/annotation.tsv \
  --condition-columns TimePoint,Infection \
  --condition-template '{TimePoint}h_{Infection}' \
  --outputs html
```

The wrapper previews the resulting condition names before analysis. Extra rows
in the annotation remain allowed; the analysis matches the two inputs by file
identifier.

## Use nonstandard column names

Common alternatives such as `Run`, `Modified Sequence`, `Precursor Charge`,
`Accession`, and `Intensity` are detected automatically. Any ambiguous header
can be supplied explicitly:

```bash
./pdtomsstats run \
  --psm psm.csv \
  --annotation annotation.csv \
  --psm-file-id-column Run \
  --psm-sequence-column 'Modified Sequence' \
  --psm-charge-column 'Precursor Charge' \
  --psm-protein-column Accession \
  --psm-intensity-column Intensity \
  --annotation-file-id-column Run \
  --outputs html
```

For independent samples, the wrapper uses `File ID` when `File Name` or
`BioReplicate` is absent. These choices are recorded in the resolved YAML. They
can also be requested explicitly with `--file-name-from-file-id` and
`--bioreplicate-from-file-id`.

## Run time-course analysis

Time-course analysis additionally needs the time column, biological group
column, reference group, and comparison group:

```bash
./pdtomsstats run \
  --psm data/my-project/psm.xlsx \
  --annotation data/my-project/annotation.tsv \
  --condition-columns TimePoint,Infection \
  --condition-template '{TimePoint}h_{Infection}' \
  --outputs html,timecourse \
  --time-column TimePoint \
  --group-column Infection \
  --reference-group Control \
  --comparison-group LGTV
```

The current maSigPro and Mfuzz report is for independent samples. It stops if
biological replicate identifiers repeat across time points.

## Add a custom figure or report section

Copy `templates/extra-figures-example.qmd`, edit it, and append it to the main
report:

```bash
./pdtomsstats run \
  --config config/local-project.yml \
  --outputs html \
  --extra-qmd custom/my-figures.qmd
```

`--extra-qmd` may be repeated. A fragment runs after the standard analysis and
can use documented analysis objects created by the report, including:

- `annotation`;
- `processed`;
- `all_comparison_output`;
- `contrast_guide`;
- `power_diagnostics`;
- `gsea_combined_table`.

Custom QMD files execute R code inside the analysis environment and should be
reviewed like any other analysis script. Use `--timecourse-extra-qmd` for the
time-course report. Advanced users can replace an entire report with
`--report-template` or `--timecourse-template`.

## Existing YAML configurations

The simple command does not replace YAML. Existing configurations continue to
work:

```bash
./pdtomsstats run \
  --config config/local-project.yml \
  --outputs html,excel \
  --protein-workbook data/my-project/proteins.xlsx
```

Command-line choices override matching YAML settings. Less common MSstats,
pathway, power, maSigPro, and Mfuzz settings remain in YAML rather than making
the normal command excessively long.

## Resolved configuration and dry runs

Every run saves:

- `pdtomsstats-resolved.yml`;
- `pdtomsstats-run.yml`;
- `pdtomsstats-timecourse-resolved.yml` when time course is requested.

These files record detected columns and all final settings. Test the choices
without running MSstats by adding `--dry-run`. Add `--non-interactive` in batch
jobs so missing or ambiguous choices fail with a clear error instead of
prompting.

See all command options with:

```bash
./pdtomsstats help
```
