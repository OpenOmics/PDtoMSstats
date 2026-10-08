# Input files

## PSM input

The PSM input may be an Excel workbook (`.xls` or `.xlsx`) or a delimited
file (`.csv`, `.tsv`, or tab-delimited `.txt`). The default Excel worksheet
name is `PSMs`. It must contain these columns exactly:

| Column | Purpose |
|---|---|
| `File ID` | Run identifier used to join the PSM and annotation files |
| `Annotated Sequence` | Peptide sequence, including modifications when present |
| `Charge` | Precursor charge |
| `Master Protein Accessions` | Protein identifier used by MSstats |
| `Quan Value` | Positive quantitative intensity |

The report also uses these columns when they are present:

- `Confidence`
- `Contaminant`
- `Modifications`
- `Master Protein Descriptions`

Column names are read with minimal repair, so spelling, capitalization, and
spaces must match.

## Annotation table

The annotation may be an Excel workbook, CSV, TSV, or tab-delimited TXT file.
Its selected worksheet or table must contain:

| Column | Purpose |
|---|---|
| `File Name` | Raw filename or readable sample name |
| `File ID` | Exact identifier found in the PSM workbook |
| `Condition` | Experimental condition; optional when it is built from other columns |
| `BioReplicate` | Biological replicate identifier |

Example:

| File Name | File ID | Condition | BioReplicate |
|---|---:|---|---:|
| Reference_1.raw | F01 | Reference | BR01 |
| Reference_2.raw | F02 | Reference | BR02 |
| Treatment_1.raw | F03 | Treatment | BR03 |
| Treatment_2.raw | F04 | Treatment | BR04 |

The annotation workbook may contain extra rows. Only `File ID` values found in
the PSM workbook are retained. Every PSM `File ID` must have exactly one
matching annotation row.

To build `Condition` from two or more annotation columns, set the column names
and a template in the configuration. For example:

```yaml
condition_columns: ["Time", "Group"]
condition_template: "{Time}h_{Group}"
```

This produces names such as `24h_Reference` and `24h_Treatment`. If no template is
given, values are joined with `condition_separator`, which defaults to `_`.

## Optional protein workbook

The formatted Excel export requires a hierarchical Proteome Discoverer protein
workbook in addition to the two files above. Its main sheet must contain:

- Rows identified as `Master Protein` in the first column.
- Peptide header rows with `Confidence` in the second column.
- Peptide sequences in the fourth column.

The protein workbook is not required to render the HTML analysis.

## Optional contrast file

Planned comparisons can be supplied in a CSV, TSV, or tab-delimited TXT file.
Use one row per nonzero contrast coefficient:

| ContrastType | Label | Condition | Weight |
|---|---|---|---:|
| pairwise | Treatment_vs_Reference | Treatment | 1 |
| pairwise | Treatment_vs_Reference | Reference | -1 |

Every label needs at least two conditions, each label/condition pair must be
unique, and the weights within a label must sum to zero. Conditions must match
the conditions created from the annotation file.

## Input checks

Run the lightweight check before a full analysis:

```bash
Rscript scripts/check_inputs.R config/my-project.yml
```
