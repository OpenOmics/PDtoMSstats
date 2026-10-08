# Configuration reference

Copy `config/example.yml` for each analysis. Paths are interpreted relative to
the repository root.

## Project and input settings

| Setting | Meaning | Default |
|---|---|---|
| `request` | Short name used in output filenames | `msstats-report` |
| `report_label` | Human-readable title inside the report | `MSstats analysis` |
| `psm_file` | PSM Excel, CSV, TSV, or tab-delimited TXT path | required |
| `psm_sheet` | Worksheet name or number for an Excel PSM input | `PSMs` |
| `annotation_file` | Annotation workbook path | required |
| `annotation_sheet` | Annotation worksheet name or number | `1` |
| `condition_columns` | Annotation columns used to construct `Condition` | `null` |
| `condition_template` | Optional template using names such as `{Time}` | `null` |
| `condition_separator` | Joiner used when no template is supplied | `_` |
| `output_dir` | HTML, CSV, and RDS destination | `results/msstats-report` |
| `figures_dir` | Figure destination | `figures/msstats-report` |
| `excluded_runs` | Optional list of `File ID` values to remove | `null` |
| `max_psm_rows` | Optional row limit for development tests only | `null` |

When `condition_columns` is null, the annotation must contain `Condition`.
When it is supplied, the workflow creates `Condition` from those columns. For
example, `condition_columns: ["Time", "Group"]` with
`condition_template: "{Time}h_{Group}"` creates `24h_Treatment`.

## Comparisons

| Setting | Meaning | Default |
|---|---|---|
| `contrast_strategy` | `all_pairwise` or `first_vs_rest` | `all_pairwise` |
| `contrasts` | Explicit numerator/denominator comparisons | `null` |
| `weighted_contrasts` | Named zero-sum contrast weights | `null` |
| `contrast_file` | Optional long-format CSV, TSV, or TXT contrast file | `null` |

Explicit comparison example:

```yaml
contrasts:
  - label: "Treatment_vs_Reference"
    numerator: "Treatment"
    denominator: "Reference"
```

Condition names must match the annotation workbook exactly. Comparison labels
must remain unique after punctuation is cleaned for filenames.

### Contrast files

Use a contrast file for experiments with many planned comparisons. It needs
the following columns:

| Column | Meaning |
|---|---|
| `ContrastType` | Short category used to prepare the interpretation guide |
| `Label` | Unique comparison name |
| `Condition` | Condition receiving this coefficient |
| `Weight` | Numeric coefficient; weights for each label must sum to zero |

Only nonzero coefficients need rows. Extra contrast types are allowed; the
guide generator gives them a generic weighted-contrast explanation. A
`linear_trend_difference` label ending in `_per_24h`, for example, is described
as a difference in linear slopes per 24 hours.

When `contrast_file` is set, leave `contrasts` and `weighted_contrasts` null.
The report validates the file, writes `msstats_contrast_guide.csv`, and saves
the definitions for the formatted workbook exporter.

## Filtering and MSstats

| Setting | Meaning | Default |
|---|---|---|
| `filter_confidence` | Confidence value retained when the column exists | `High` |
| `remove_contaminants` | Remove contaminant-flagged PSMs | `true` |
| `remove_shared_peptides` | Use only unique peptides | `true` |
| `remove_single_peptide_proteins` | Remove proteins with one peptide | `false` |
| `remove_few_measurements` | Let MSstats remove sparsely measured features | `false` |
| `normalization` | MSstats normalization method | `equalizeMedians` |
| `summary_method` | Protein summarization method | `TMP` |
| `mb_impute` | Enable model-based imputation | `true` |
| `number_of_cores` | Cores supplied to MSstats | `1` |

## Differential plots and power

| Setting | Meaning | Default |
|---|---|---|
| `volcano_p_cutoff` | Adjusted p-value threshold | `0.05` |
| `volcano_fc_cutoff` | Absolute log2 fold-change threshold | `1` |
| `volcano_top_labels` | Maximum labels per volcano plot | `10` |
| `power_alpha` | Type-I error rate | `0.05` |
| `power_target` | Target statistical power | `0.80` |
| `power_effect_log2fc` | Target absolute log2 fold change | `1` |

Less commonly changed volcano, QC, and power display settings are documented
in the parameter block at the top of `msstats-psm-report.qmd`.

## Pathway analysis

| Setting | Meaning | Default |
|---|---|---|
| `organism_package` | Bioconductor organism annotation package | `org.Hs.eg.db` |
| `run_gsea` | Run GO Biological Process GSEA | `true` |
| `gsea_pvalue_cutoff` | GSEA display threshold | `0.05` |
| `gsea_min_gene_set_size` | Minimum tested gene-set size | `100` |
| `gsea_max_gene_set_size` | Maximum tested gene-set size | `500` |

Install the selected organism package before rendering.
