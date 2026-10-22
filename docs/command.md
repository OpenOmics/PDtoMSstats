# PDtoMSstats commands

The top-level `pdtomsstats` launcher standardizes project creation, validation,
local/container execution, Slurm submission, status, and provenance. It calls
the same generalized analysis and workbook functions as the individual
scripts; the command layer does not change the scientific models.

See [standardized projects](standardized-projects.md) for `init`, `validate`,
`submit`, `status`, execution profiles, and the standard directory layout.

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

The main and time-course HTML reports and default formatted workbook are
grouped under the configured results directory's `main/` subdirectory.
Supporting main-analysis CSV/RDS/YAML files are grouped under `supporting/`,
and time-course supporting files remain under `timecourse/`.

## Run multiple independent analyses

Use `--batch` when one project contains several independent PSM analyses. No
batch manifest or shell loop is needed. Files in the project's `data/`
directory define the analyses:

```text
data/
├── annotation.xlsx
├── bma-il10__psm.xlsx
├── bma-il10__protein.xlsx
├── bma-il13__psm.xlsx
├── bma-il13__protein.xlsx
├── tmes-il10__psm.xlsx
├── tmes-il10__protein.xlsx
├── tmes-il13__psm.xlsx
└── tmes-il13__protein.xlsx
```

The exact convention is `<analysis-id>__psm.xlsx` and
`<analysis-id>__protein.xlsx`. The double underscore separates the analysis ID
from its file role. Role names and the `.xlsx` extension are lowercase. An
analysis ID may contain letters, numbers, periods, hyphens, and underscores.

`annotation.xlsx` is shared by default. An optional
`<analysis-id>__annotation.xlsx` overrides it for one analysis. The same rule
applies to optional contrasts: `contrasts.tsv` is shared and
`<analysis-id>__contrasts.tsv` is an analysis-specific override. Explicit
`--annotation` or `--contrast-file` options override automatic discovery.

Validate every discovered analysis without submitting jobs:

```bash
./pdtomsstats validate --project /path/to/project \
  --batch --outputs html,excel
```

Run or submit the complete batch:

```bash
./pdtomsstats run --project /path/to/project \
  --batch --outputs html,excel
```

Before execution or submission, the launcher validates every discovered
analysis. Excel output requires every PSM file to have a matching protein
workbook. With a Slurm-default profile, one independent job is submitted per
analysis and all IDs are saved in a batch record. Results are isolated under
`results/<analysis-id>/`, each with its own `main/`, `figures/`, and
`supporting/` directories.

Use another discovery directory only when needed:

```bash
./pdtomsstats run --project /path/to/project \
  --batch --batch-data-dir /path/to/project/another-data-directory \
  --outputs html,excel
```

Per-analysis path and naming options such as `--psm`, `--protein-workbook`,
`--request`, and `--output-dir` are intentionally assigned by batch discovery.
All shared scientific options—column mappings, filtering, normalization,
condition construction, thresholds, GSEA, and output selection—remain
available on the batch command.

When `html` is requested, the main analysis runs and refreshes its report and
analysis RDS. An `excel`-only or `timecourse`-only run reuses the existing
`supporting/msstats_workbook_export_objects.rds`; it does not silently rerun
the main analysis. If that file is absent, first run `--outputs html`, or
explicitly add `--with-dependencies` to create the missing prerequisite. Files
in the legacy results-root location remain usable.

```bash
./pdtomsstats run \
  --config config/local-my-project.yml \
  --timecourse-config config/local-my-project-timecourse.yml \
  --outputs timecourse \
  --with-dependencies
```

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

### Set the Excel fold-change reporting limit

Use `--maximum-allowed-fold-change 100` (the default) or set
`maximum_allowed_fold_change: 100` in YAML. This bounds the appended Ratio and
log2FC in the protein/peptide workbook views to `[0.01, 100]` and
approximately `[-6.643856, 6.643856]`. Infinite estimates and finite values
outside the bounds are capped for these views. Model results, CSV/RDS files,
DE worksheets, and `All MSstats Results` retain the original estimates.
See [workbook export](workbook-export.md) for sorting and gradient details.

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
  --protein-workbook data/my-project/proteins.xlsx \
  --time-column TimePoint \
  --group-column Infection \
  --reference-group Control \
  --comparison-group LGTV
```

The time-course report fits orthogonal-polynomial maSigPro and limma natural
splines, then runs Mfuzz independently on each method's significant proteins.
It is for independent samples and stops if biological replicate identifiers
repeat across time points.

When `--protein-workbook` is supplied, the interactive trajectory dashboard
also shows the gene symbol parsed from each protein description's `GN=` field.
This annotation does not enter any statistical model.

The default selection thresholds can be overridden from the command line. For
example, add `--model-fdr 0.05 --limma-interaction-fdr 0.05
--coefficient-alpha 0.05 --min-r-squared 0.60`. Use `--polynomial-degree` and
`--spline-df` to change the corresponding basis sizes.

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

Every run saves the following under `supporting/`:

- `pdtomsstats-resolved.yml`;
- `pdtomsstats-run.yml`.

The time-course resolved configuration remains under `timecourse/` when that
output is requested.

These files record detected columns and all final settings. Test the choices
without running MSstats by adding `--dry-run`. Add `--non-interactive` in batch
jobs so missing or ambiguous choices fail with a clear error instead of
prompting.

See all command options with:

```bash
./pdtomsstats help
```
