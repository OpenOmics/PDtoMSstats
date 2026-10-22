# Standardized projects and commands

PDtoMSstats separates scientific analysis from execution policy. The existing
R scripts and Quarto reports perform the analysis. The top-level `pdtomsstats`
command creates projects, selects outputs, starts containers, submits Slurm
jobs, and records execution details.

## Command summary

| Command | Action |
|---|---|
| `init` | Create a project layout and editable YAML/contrast templates |
| `validate` | Resolve paths, inspect inputs, and write resolved configuration without analysis |
| `run` | Use the selected profile's default mode; Biowulf submits with `sbatch` |
| `submit` | Explicit alias for Slurm submission |
| `status` | Report the latest recorded job, log tail, and generated reports/workbooks |
| `version` | Report workflow, Git, profile, runtime, and container versions |

These are orchestration commands. They do not replace the generalized R
analysis scripts.

## Initialize a project

On NIH Biowulf, create a main plus time-course project with:

```bash
/data/Proteomics_IDSS/prod/PDtoMSstats/pdtomsstats init \
  --project /data/Proteomics_IDSS/projects/my-project \
  --profile biowulf \
  --modules main,timecourse \
  --label "My proteomics project"
```

This creates:

```text
my-project/
├── .pdtomsstats/
│   └── project.yml
├── config/
│   ├── my-project-main.yml
│   ├── my-project-timecourse.yml
│   └── my-project-contrasts.tsv
├── data/
├── logs/
├── results/
│   ├── figures/
│   ├── main/
│   ├── supporting/
│   └── timecourse/
└── tmp/
```

The hidden metadata file remembers the selected execution profile. It does not
contain secrets. Templates are not overwritten unless `--force` is supplied.
For main analysis only, use `--modules main`.

The `biowulf` profile sets the group to `Proteomics_IDSS`, makes project
directories setgid, applies group default ACLs when `setfacl` is available,
and uses `umask 0007` for created results. Existing files copied into a project
are updated recursively when permissions allow; the launcher warns if group
ownership cannot be assigned.

## Validate before running

Edit all `REPLACE_*` values, then run:

```bash
PDT=/data/Proteomics_IDSS/prod/PDtoMSstats/pdtomsstats
PROJECT=/data/Proteomics_IDSS/projects/my-project

"$PDT" validate \
  --project "$PROJECT" \
  --config "$PROJECT/config/my-project-main.yml" \
  --timecourse-config "$PROJECT/config/my-project-timecourse.yml" \
  --outputs html,timecourse
```

Validation performs a dry run and writes resolved configurations. It does not
execute MSstats, Quarto, or workbook export.

## Select outputs

The launcher accepts one output or any comma-separated combination:

```bash
# Main analysis and HTML report
"$PDT" run --project "$PROJECT" \
  --config "$PROJECT/config/my-project-main.yml" --outputs html

# Workbook from an existing main-analysis RDS
"$PDT" run --project "$PROJECT" \
  --config "$PROJECT/config/my-project-main.yml" \
  --protein-workbook "$PROJECT/data/proteins.xlsx" --outputs excel

# Time course from an existing main-analysis RDS
"$PDT" run --project "$PROJECT" \
  --config "$PROJECT/config/my-project-main.yml" \
  --timecourse-config "$PROJECT/config/my-project-timecourse.yml" \
  --protein-workbook "$PROJECT/data/proteins.xlsx" \
  --outputs timecourse
```

The protein workbook is optional for model fitting, but supplying it adds the
description-derived `GN=` gene symbol to the interactive trajectory dashboard.

With the Biowulf profile, each plain `run` command submits a detached Slurm job
and returns after `sbatch` accepts it. Use `--mode slurm` to request this
explicitly, or `--mode local` to execute in the current allocation. Without an
execution profile, Docker runs locally.

`excel` and `timecourse` reuse
`results/supporting/msstats_workbook_export_objects.rds`. They stop when it is
absent so that a supposedly downstream-only run cannot silently repeat a large
main analysis. Add `--with-dependencies` to generate that missing prerequisite.
For compatibility, existing objects in the legacy results-root location are
still recognized.

After a complete run, the results are organized as:

```text
results/
├── main/
│   ├── my-project.html
│   ├── my-project-timecourse.html
│   └── proteins_MSstats.xlsx
├── timecourse/
│   └── time-course CSV/RDS/YAML files
├── figures/
│   └── main and time-course figures
└── supporting/
    ├── msstats_workbook_export_objects.rds
    ├── main-analysis CSV/RDS files
    ├── pdtomsstats-resolved.yml
    └── pdtomsstats-run.yml
```

An explicit `--excel-output` path is still honored instead of the default
`main/` location.

## Multiple independent analyses

A project can submit several separate analyses without a TSV manifest or a
shell loop. Give each PSM/protein pair a shared analysis ID:

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

The filename pairing convention is strict, but role suffix capitalization is
flexible:

- `<analysis-id>__PSM.xlsx` defines an independent analysis;
- `<analysis-id>__protein.xlsx` or `<analysis-id>__proteins.xlsx` is its
  matching workbook source and is required when `excel` is requested;
- `annotation.xlsx` is shared by all analyses;
- `<analysis-id>__annotation.xlsx` optionally overrides the shared annotation;
- `contrasts.tsv` is an optional shared contrast definition;
- `<analysis-id>__contrasts.tsv` optionally overrides shared contrasts.

The `PSM`, `protein`/`proteins`, and `.xlsx` portions are case-insensitive.
Ambiguous duplicate protein matches are rejected.

Validate the discovered set first when reviewing a new project:

```bash
"$PDT" validate --project "$PROJECT" --batch --outputs html,excel
```

Submit it with one command:

```bash
"$PDT" run --project "$PROJECT" --batch --outputs html,excel
```

`run --batch` repeats the validation before any work is submitted, then creates
one independent Slurm job per analysis. Outputs are written to
`results/<analysis-id>/`. The combined job registry is retained under
`.pdtomsstats/batches/`, and `pdtomsstats status --project "$PROJECT"` reports
the latest batch automatically. Use `status --batch` to request the most recent
batch explicitly after a later single-analysis submission.

The same mode works for a project containing only one independent PSM/protein
pair. With `annotation.xlsx`, `experiment__PSM.xlsx`, and
`experiment__protein.xlsx` under `data/`, `run --batch` submits one job and
writes `results/experiment/`. The generated main YAML and contrast TSV do not
need to be edited for conventionally named batch inputs.

Custom filenames do not force YAML use. For one analysis, either supply
`--psm`, `--annotation`, and `--protein-workbook` directly, or edit the
generated main YAML and pass `--protein-workbook` with the run command. For
several custom-named independent analyses, use separate explicit
runs/configurations or rename them to the batch convention. See
[choose batch or explicit inputs](command.md#choose-batch-or-explicit-inputs)
for complete examples.

## Submit and monitor

```bash
"$PDT" run \
  --project "$PROJECT" \
  --config "$PROJECT/config/my-project-main.yml" \
  --timecourse-config "$PROJECT/config/my-project-timecourse.yml" \
  --outputs html,timecourse,excel \
  --protein-workbook "$PROJECT/data/proteins.xlsx" \
  --cpus 2 --memory 64G --walltime 12:00:00
```

The generated `.slurm` file and `%j` stdout/stderr logs are retained in
`logs/`. The latest single job ID or complete batch registry is stored under
`.pdtomsstats/`.

`pdtomsstats submit` remains available as an explicit synonym for
`pdtomsstats run --mode slurm`.

```bash
"$PDT" status --project "$PROJECT"
```

## Profiles

Profiles live under `config/profiles/`. They contain only execution settings:
container runtime and image, module, group permissions, isolation behavior,
and default Slurm resources. Experiment design remains in the project YAML.

The supplied `biowulf.yml` profile uses:

- Apptainer 1.4.5;
- `/data/Proteomics_IDSS/SIFs/pdtomsstats_0.2.4.sif`;
- a stable `/data/Proteomics_IDSS` path alias while also exposing the resolved
  `/vf/users/Proteomics_IDSS` project path;
- detached Slurm execution as the default `run` mode;
- `--containall` and `--cleanenv`;
- explicit workflow, project, and job-temporary binds;
- no `HOME` environment override.

An option supplied to `run` or `submit` overrides its profile default. For
example, `--mode local` stays in the current allocation, and
`--image /path/to/new.sif` tests a new image without editing the shared profile.

## Provenance

Use the following before or after a run:

```bash
"$PDT" version --project "$PROJECT"
```

Every analysis also writes resolved YAML and `pdtomsstats-run.yml` under
`results/supporting/`. The run manifest records the requested outputs, dependency
behavior, analysis RDS, configurations, workbook input, workflow version and
commit, container, execution profile/mode, Slurm job ID, and creation time.
