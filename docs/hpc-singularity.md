# Running on HPC with SingularityCE or Apptainer

PDtoMSstats can run on an HPC system without Docker. SingularityCE and
Apptainer can convert the published OCI image to an immutable Singularity
Image Format (`.sif`) file. The R reports and helper scripts do not change.

Commands in this guide use `singularity`. If the HPC system provides
`apptainer`, replace only the command name. Ask the HPC support team which
module, scheduler settings, storage locations, and usage policies apply at the
site.

## Overview

The normal HPC workflow is:

1. clone the PDtoMSstats source repository;
2. pull the released container to a `.sif` file once;
3. place private inputs under the ignored `data` directory;
4. validate the inputs on an allocated compute node;
5. submit the analysis as an interactive or batch job;
6. read the results from the host `results` and `figures` directories.

Do not run a full analysis on a shared login node unless local policy allows
it. Pulling the image and editing configurations are normally appropriate on a
login or transfer node.

## Check the HPC software

```bash
module avail singularity apptainer
module load singularity
singularity --version
```

The exact module name is site-specific. If `singularity` is unavailable after
loading the module, try `apptainer --version`.

## Clone the repository

```bash
git clone https://github.com/OpenOmics/PDtoMSstats.git
cd PDtoMSstats
```

For a private repository, use the Git authentication method approved by the
organization and HPC administrators. Do not save a password or access token in
the repository.

## Pull the released image

Choose a container location with adequate quota. The image can be shared by
multiple analyses and does not need to be copied into every project.

```bash
mkdir -p containers

singularity pull \
  containers/pdtomsstats_0.1.1.sif \
  docker://ghcr.io/openomics/pdtomsstats:0.1.1
```

Pulling converts the multi-platform GitHub Container Registry image to a SIF
for the HPC system's architecture. Compute nodes often lack internet access,
so complete this step before submitting the job.

If the home-directory quota is small, put the Singularity cache in scratch
storage before pulling:

```bash
export SINGULARITY_CACHEDIR="/path/to/scratch/$USER/singularity-cache"
mkdir -p "$SINGULARITY_CACHEDIR"
```

For Apptainer, use `APPTAINER_CACHEDIR` instead.

### Private GHCR package

If the container package is private, authenticate before pulling:

```bash
singularity registry login \
  --username YOUR_GITHUB_USERNAME \
  docker://ghcr.io
```

Enter a GitHub personal access token with `read:packages` permission when
prompted. Never include the token in a shell script, Slurm file, YAML
configuration, or Git commit.

Some older Singularity versions use an interactive pull instead:

```bash
singularity pull --docker-login \
  containers/pdtomsstats_0.1.1.sif \
  docker://ghcr.io/openomics/pdtomsstats:0.1.1
```

The official documentation explains
[OCI image conversion](https://docs.sylabs.io/guides/latest/user-guide/singularity_and_docker.html)
and [registry authentication](https://docs.sylabs.io/guides/latest/user-guide/registry.html).

## Prepare the project

Follow the [getting-started guide](getting-started.md) to place inputs under
`data/<project>/` and copy `config/example.yml` to a local configuration. Use
relative paths with forward slashes in YAML.

The repository is explicitly mounted at `/workspace` in the examples below.
This reproduces the Docker Compose layout and makes host inputs and outputs
available inside the container.

## Check the container environment

From the repository root:

```bash
singularity exec \
  --cleanenv \
  --bind "$PWD:/workspace" \
  --pwd /workspace \
  --env HOME=/tmp,OMP_NUM_THREADS=1,OPENBLAS_NUM_THREADS=1,MKL_NUM_THREADS=1 \
  containers/pdtomsstats_0.1.1.sif \
  Rscript scripts/check_environment.R
```

The command should finish with `PDtoMSstats environment check: PASS`.

The options have these purposes:

| Option | Purpose |
|---|---|
| `--cleanenv` | Prevent host R settings and libraries from changing the container environment |
| `--bind` | Make the project directory available at `/workspace` with normal user write permissions |
| `--pwd` | Run commands from the project root inside the container |
| `--env HOME=/tmp` | Give R and Quarto a writable temporary home |
| thread variables | Prevent BLAS libraries from consuming unrequested CPU cores |

See the official [Apptainer execution reference](https://apptainer.org/docs/user/latest/cli/apptainer_exec.html)
for equivalent options.

## Interactive analysis

First request a compute allocation. A typical Slurm request is:

```bash
srun --pty \
  --cpus-per-task=2 \
  --mem=32G \
  --time=04:00:00 \
  bash
```

The correct partition, account, and resource limits depend on the HPC site.
After the allocated shell opens, load Singularity and enter the repository:

```bash
module load singularity
cd /path/to/PDtoMSstats
```

Validate the inputs:

```bash
singularity exec \
  --cleanenv \
  --bind "$PWD:/workspace" \
  --pwd /workspace \
  --env HOME=/tmp,OMP_NUM_THREADS=1,OPENBLAS_NUM_THREADS=1,MKL_NUM_THREADS=1 \
  containers/pdtomsstats_0.1.1.sif \
  Rscript scripts/check_inputs.R config/local-my-project.yml
```

Run the main MSstats analysis:

```bash
singularity exec \
  --cleanenv \
  --bind "$PWD:/workspace" \
  --pwd /workspace \
  --env HOME=/tmp,OMP_NUM_THREADS=1,OPENBLAS_NUM_THREADS=1,MKL_NUM_THREADS=1 \
  containers/pdtomsstats_0.1.1.sif \
  Rscript scripts/run_pipeline.R config/local-my-project.yml
```

The host `results` and `figures` directories receive the outputs.

## Optional maSigPro and Mfuzz analysis

Supplying a second YAML file is the time-course trigger:

```bash
singularity exec \
  --cleanenv \
  --bind "$PWD:/workspace" \
  --pwd /workspace \
  --env HOME=/tmp,OMP_NUM_THREADS=1,OPENBLAS_NUM_THREADS=1,MKL_NUM_THREADS=1 \
  containers/pdtomsstats_0.1.1.sif \
  Rscript scripts/run_pipeline.R \
  config/local-my-project.yml \
  config/local-my-project-timecourse.yml
```

With only the main configuration, the workflow stops after MSstats. See the
[time-course guide](timecourse.md) for design assumptions and interpretation.

## Optional formatted workbook

After the main report finishes:

```bash
singularity exec \
  --cleanenv \
  --bind "$PWD:/workspace" \
  --pwd /workspace \
  --env HOME=/tmp,OMP_NUM_THREADS=1,OPENBLAS_NUM_THREADS=1,MKL_NUM_THREADS=1 \
  containers/pdtomsstats_0.1.1.sif \
  Rscript scripts/export_workbook.R \
  data/my-project/proteins.xlsx \
  results/my-project
```

## Slurm batch job

Save this as `run-pdtomsstats.slurm` and replace the paths and Slurm resources:

```bash
#!/bin/bash
#SBATCH --job-name=pdtomsstats
#SBATCH --cpus-per-task=2
#SBATCH --mem=32G
#SBATCH --time=08:00:00
#SBATCH --output=pdtomsstats-%j.out

set -euo pipefail

module load singularity

PROJECT_DIR="/path/to/PDtoMSstats"
IMAGE="/path/to/containers/pdtomsstats_0.1.1.sif"
MAIN_CONFIG="config/local-my-project.yml"

cd "$PROJECT_DIR"

singularity exec \
  --cleanenv \
  --bind "$PROJECT_DIR:/workspace" \
  --pwd /workspace \
  --env HOME=/tmp,OMP_NUM_THREADS=1,OPENBLAS_NUM_THREADS=1,MKL_NUM_THREADS=1 \
  "$IMAGE" \
  Rscript scripts/run_pipeline.R "$MAIN_CONFIG"
```

Submit it with:

```bash
sbatch run-pdtomsstats.slurm
```

To include the time-course stage, add:

```bash
TIMECOURSE_CONFIG="config/local-my-project-timecourse.yml"
```

and change the final command arguments to:

```bash
Rscript scripts/run_pipeline.R "$MAIN_CONFIG" "$TIMECOURSE_CONFIG"
```

## Resource settings

- `number_of_cores` in the main YAML must not exceed Slurm
  `--cpus-per-task`.
- Start with 32 GB memory for a moderate study and adjust based on PSM table
  size and observed peak usage.
- Request enough wall time for the main report and optional time-course stage.
- Store the SIF and input files on storage visible from compute nodes.
- Use job-local scratch for caches when recommended by the HPC administrators.

For the most reproducible comparison with previous results, keep
`number_of_cores: 1` and request at least one CPU.

## Common problems

### The image cannot be pulled

The package may be private, the login token may lack `read:packages`, or the
login node may not have external network access. Authenticate on a permitted
transfer node or ask HPC support to mirror the SIF to shared storage.

### A path is missing inside the container

Run from the repository root and confirm that the bind source is correct:

```bash
pwd
singularity exec --bind "$PWD:/workspace" \
  containers/pdtomsstats_0.1.1.sif ls /workspace
```

### Permission denied while writing results

Confirm that the host repository, `results`, and `figures` directories are
writable. Singularity normally writes as the submitting user rather than as
root.

### The job is killed

Check the scheduler accounting record. An out-of-memory termination requires a
larger `--mem` request; a timeout requires a longer `--time` request.

### The `--env` option is unavailable

Very old Singularity versions may require `SINGULARITYENV_` variables. Ask HPC
support whether a newer module is available before adapting the command.
