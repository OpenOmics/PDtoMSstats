# HPC with Apptainer and Slurm

PDtoMSstats has a host-side launcher for standardized HPC projects. The
launcher applies the container isolation, bind mounts, group permissions,
temporary directory, and Slurm settings; the scientific R scripts remain the
same as Docker and native execution.

This guide uses the supplied NIH Biowulf profile. Other sites can copy
`config/profiles/biowulf.yml` and change only site-specific execution values.

## One-time group installation

Clone the workflow into the shared production directory and select a reviewed
commit or release:

```bash
cd /data/Proteomics_IDSS/prod
git clone https://github.com/OpenOmics/PDtoMSstats.git
cd PDtoMSstats
git rev-parse --short HEAD
```

For production, record the printed commit and use the reviewed commit or tag
chosen by the group. Do not assume that a moving branch will remain unchanged.

Load Apptainer and pull the matching released container once:

```bash
module load apptainer/1.4.5
apptainer --version

mkdir -p /data/Proteomics_IDSS/SIFs
apptainer pull \
  /data/Proteomics_IDSS/SIFs/pdtomsstats_0.2.1.sif \
  docker://ghcr.io/openomics/pdtomsstats:0.2.1
```

Verify the installed image:

```bash
apptainer exec --containall --cleanenv \
  --bind /data/Proteomics_IDSS/prod/PDtoMSstats:/opt/PDtoMSstats:ro \
  --pwd /opt/PDtoMSstats \
  /data/Proteomics_IDSS/SIFs/pdtomsstats_0.2.1.sif \
  Rscript scripts/check_environment.R
```

The final line should be `PDtoMSstats environment check: PASS`.

## Create a project

```bash
PDT=/data/Proteomics_IDSS/prod/PDtoMSstats/pdtomsstats
PROJECT=/data/Proteomics_IDSS/projects/my-project

"$PDT" init \
  --project "$PROJECT" \
  --profile biowulf \
  --modules main,timecourse \
  --label "My proteomics project"
```

Copy the PSM, annotation, and optional Proteome Discoverer protein workbook to
`$PROJECT/data/`. Edit the generated files under `$PROJECT/config/`. Keep
contrast definitions in `config/`, because they are model configuration rather
than raw input data.

The generated project metadata remembers `biowulf`; subsequent commands do not
need to repeat `--profile biowulf`.

## Validate

```bash
"$PDT" validate \
  --project "$PROJECT" \
  --config "$PROJECT/config/my-project-main.yml" \
  --timecourse-config "$PROJECT/config/my-project-timecourse.yml" \
  --outputs html,timecourse,excel \
  --protein-workbook "$PROJECT/data/proteins.xlsx"
```

Validation reads input headers and annotation, checks design choices, and
writes resolved YAML without starting an analysis.

## Run as a detached Slurm job

The Biowulf profile sets `default_mode: slurm`. Like Cell-seek, plain
`pdtomsstats run` writes a job script, submits it, and returns after `sbatch`
accepts the job:

```bash
"$PDT" run \
  --project "$PROJECT" \
  --config "$PROJECT/config/my-project-main.yml" \
  --timecourse-config "$PROJECT/config/my-project-timecourse.yml" \
  --protein-workbook "$PROJECT/data/proteins.xlsx" \
  --outputs html,timecourse,excel \
  --cpus 2 \
  --memory 64G \
  --walltime 12:00:00
```

Defaults may be omitted. They come from `config/profiles/biowulf.yml`. A
submission writes the exact generated Slurm script to `logs/`, submits it, and
records its job ID.

`pdtomsstats run --mode slurm` requests the same behavior explicitly.
`pdtomsstats submit` is retained as a descriptive alias.

Monitor it with:

```bash
"$PDT" status --project "$PROJECT"
```

The command uses `squeue` for an active job and `sacct` after completion, then
shows the latest log tail and generated HTML/XLSX files.

## Run inside an interactive allocation

After obtaining an interactive allocation, override the profile default with
`--mode local`:

```bash
"$PDT" run \
  --mode local \
  --project "$PROJECT" \
  --config "$PROJECT/config/my-project-main.yml" \
  --outputs html
```

Do not run a full analysis on a shared login node unless site policy explicitly
allows it.

## Run individual outputs

Main HTML report:

```bash
"$PDT" run --project "$PROJECT" \
  --config "$PROJECT/config/my-project-main.yml" \
  --outputs html
```

Excel workbook after the main report exists:

```bash
"$PDT" run --project "$PROJECT" \
  --config "$PROJECT/config/my-project-main.yml" \
  --protein-workbook "$PROJECT/data/proteins.xlsx" \
  --outputs excel
```

Time-course report after the main report exists:

```bash
"$PDT" run --project "$PROJECT" \
  --config "$PROJECT/config/my-project-main.yml" \
  --timecourse-config "$PROJECT/config/my-project-timecourse.yml" \
  --protein-workbook "$PROJECT/data/proteins.xlsx" \
  --outputs timecourse
```

The protein workbook is optional for model fitting. Supplying it adds the
description-derived `GN=` gene symbol to the interactive trajectory dashboard.

The Excel and time-course stages reuse
`results/msstats_workbook_export_objects.rds`. If it does not exist, the
launcher stops. Add `--with-dependencies` when the main analysis should be
generated automatically first.

## Home-directory isolation

The Biowulf profile makes `--containall` and `--cleanenv` mandatory by default.
Apptainer therefore creates an isolated container home rather than binding the
host home. The launcher binds only:

- the workflow read-only at `/opt/PDtoMSstats`;
- the selected project at its absolute path;
- job scratch at `/jobtmp`.

It deliberately does not pass `HOME=/tmp`, and removes inherited
`APPTAINERENV_HOME` and `SINGULARITYENV_HOME` variables. The image cannot set
mount policy itself because mounts are established by Apptainer before the
container command starts.

The launcher also uses the selected job scratch as `APPTAINER_TMPDIR` and
removes the legacy `SINGULARITY_TMPDIR`, avoiding conflicting temporary-
directory settings.

The launcher does not create, remove, or alter host filesystem symlinks. A
root-owned symlink under a shared filesystem is outside the R analysis and
should be reviewed by the HPC storage administrators.

## Group access

Initialization uses group `Proteomics_IDSS`, setgid directories, group
read/write/execute permissions, default ACLs when supported, and `umask 0007`.
To correct permissions on files that existed before initialization:

```bash
chgrp -R Proteomics_IDSS "$PROJECT"
chmod -R g+rwX,o-rwx "$PROJECT"
find "$PROJECT" -type d -exec chmod g+s {} +
find "$PROJECT" -type d -exec \
  setfacl -m d:g:Proteomics_IDSS:rwx,d:m::rwx,d:o::--- {} +
```

## Resource and version checks

`number_of_cores` in the main YAML must not exceed Slurm `--cpus`. Large PSM
tables and formatted workbooks can need substantially more memory than small
test datasets. Check completed jobs with `sacct` and adjust future requests.

Record the installation pairing with:

```bash
"$PDT" version --project "$PROJECT"
```

The output reports the workflow version and Git commit alongside the profile,
runtime, and SIF. A production release should publish the workflow tag and
container image together.

## Common errors

### SIF not found

Check the `image` path in `config/profiles/biowulf.yml`, or override it for one
run with `--image /absolute/path/image.sif`.

### Apptainer is unavailable

Load the module named in the profile. The launcher attempts this automatically,
but a cluster may require its module initialization in the login shell.

### Permission denied

Check group membership with `id`, inspect the parent directory permissions,
and apply the group-access correction above. The submitter must be able to
write `logs/`, `results/`, and `tmp/`.

### Job is killed

Use `sacct` or `pdtomsstats status`. Increase `--memory` for an out-of-memory
state or `--walltime` for a timeout.
