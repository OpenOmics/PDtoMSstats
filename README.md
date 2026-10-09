# PDtoMSstats

PDtoMSstats is a configuration-driven workflow that takes Proteome Discoverer
PSM data through quality control, MSstats protein summarization and planned
comparisons, optional formatted Excel export, and independent-sample
time-course analysis with maSigPro and Mfuzz.

Docker is the recommended way to run the workflow. The same image is used on
Linux, Windows, Intel macOS, and Apple Silicon macOS, so users do not need to
install R, Quarto, compilers, or individual R packages on the host computer.

## Start here

If you are not comfortable with command-line tools, use the
[step-by-step getting started guide](docs/getting-started.md). It explains how
to download the repository, install Docker Desktop, run the demonstration,
add your own files, edit the small configuration file, and find the results.
No R programming is required for routine use.

In brief, a user supplies:

- a Proteome Discoverer PSM table;
- a sample annotation table;
- a short YAML configuration file based on the provided template.

The workflow returns a self-contained HTML report, result tables, figures,
saved analysis objects, and, when a Proteome Discoverer protein workbook is
provided, a formatted Excel workbook.

```mermaid
flowchart LR
    PSM[PSM table] --> MAIN[MSstats report]
    ANN[Sample annotation] --> MAIN
    CFG[YAML configuration] --> MAIN
    MAIN --> HTML[Self-contained HTML]
    MAIN --> TABLES[CSV and RDS outputs]
    TABLES --> TIME[maSigPro and Mfuzz]
    TIME --> THTML[Time-course HTML and tables]
    PROTEIN[Optional PD protein workbook] --> XLSX[Formatted workbook]
    TABLES --> XLSX
```

## Quick test with Docker

Requirements:

- Docker Desktop on Windows or macOS, or Docker Engine with the Compose plugin
  on Linux;
- at least 8 GB RAM available to Docker; 12–16 GB is preferable for large
  studies.

Download or clone this repository, open a terminal in its top-level folder,
then build the image and check the installed environment:

```bash
docker compose build
docker compose run --rm pdtomsstats
```

Run only the main MSstats stage of the bundled de-identified example:

```bash
docker compose run --rm pdtomsstats \
  Rscript scripts/run_pipeline.R config/example-data.yml
```

To also test the optional time-course stage, add its configuration:

```bash
docker compose run --rm pdtomsstats \
  Rscript scripts/run_pipeline.R \
  config/example-data.yml \
  config/example-data-timecourse.yml
```

Outputs appear on the host under `results/example/` and figures under
`figures/example/`. The example contains synthetic identifiers and is intended
only to verify the software.

See [Docker instructions](docs/docker.md) and the
[example walkthrough](docs/example.md) for Windows, macOS, and Linux details.

## HPC with Singularity or Apptainer

The same published container can run on an HPC system without Docker. No R
analysis code changes are required. If the site provides `apptainer` rather
than `singularity`, replace the command name below; the arguments are the same.

Pull the released container once, normally on a login or transfer node with
internet access:

```bash
module load singularity
mkdir -p containers
singularity pull containers/pdtomsstats_0.1.0.sif \
  docker://ghcr.io/openomics/pdtomsstats:0.1.0
```

For a private GitHub Container Registry package, first use
`singularity registry login --username YOUR_GITHUB_USERNAME docker://ghcr.io`
and enter a GitHub token with `read:packages` permission. Never put the token
in a job script.

### Interactive compute node

Request an interactive compute allocation according to local policy. For a
Slurm cluster, a typical request is:

```bash
srun --pty --cpus-per-task=2 --mem=32G --time=04:00:00 bash
```

From the PDtoMSstats repository root on the allocated node, run the main
MSstats stage:

```bash
singularity exec \
  --cleanenv \
  --bind "$PWD:/workspace" \
  --pwd /workspace \
  --env HOME=/tmp,OMP_NUM_THREADS=1,OPENBLAS_NUM_THREADS=1,MKL_NUM_THREADS=1 \
  containers/pdtomsstats_0.1.0.sif \
  Rscript scripts/run_pipeline.R config/local-my-project.yml
```

Add the time-course configuration as the second argument to run maSigPro and
Mfuzz after MSstats:

```bash
singularity exec \
  --cleanenv \
  --bind "$PWD:/workspace" \
  --pwd /workspace \
  --env HOME=/tmp,OMP_NUM_THREADS=1,OPENBLAS_NUM_THREADS=1,MKL_NUM_THREADS=1 \
  containers/pdtomsstats_0.1.0.sif \
  Rscript scripts/run_pipeline.R \
  config/local-my-project.yml \
  config/local-my-project-timecourse.yml
```

Do not run a full analysis on a shared login node unless the HPC administrators
explicitly allow it.

### Slurm batch job

Save the following as `run-pdtomsstats.slurm`, replacing the two paths:

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
IMAGE="/path/to/pdtomsstats_0.1.0.sif"

cd "$PROJECT_DIR"

singularity exec \
  --cleanenv \
  --bind "$PROJECT_DIR:/workspace" \
  --pwd /workspace \
  --env HOME=/tmp,OMP_NUM_THREADS=1,OPENBLAS_NUM_THREADS=1,MKL_NUM_THREADS=1 \
  "$IMAGE" \
  Rscript scripts/run_pipeline.R config/local-my-project.yml
```

Submit it with `sbatch run-pdtomsstats.slurm`. The YAML `number_of_cores` must
not exceed `--cpus-per-task`. See the complete
[Singularity/Apptainer HPC guide](docs/hpc-singularity.md) for input checks,
time-course execution, Excel export, private-registry access, and
troubleshooting.

## Analyze a new project

The main report needs:

1. a Proteome Discoverer PSM Excel, CSV, TSV, or tab-delimited TXT file;
2. a sample annotation Excel, CSV, TSV, or TXT file;
3. a YAML configuration copied from `config/example.yml`.

Private inputs can be placed under `data/<project>/`; all data are ignored by
Git except the bundled public example.

```bash
cp config/example.yml config/local-my-project.yml
```

Edit the file paths and design columns, then validate and render:

```bash
docker compose run --rm pdtomsstats \
  Rscript scripts/check_inputs.R config/local-my-project.yml

docker compose run --rm pdtomsstats \
  Rscript scripts/render_report.R config/local-my-project.yml
```

The annotation may contain extra rows. PDtoMSstats matches the PSM and
annotation tables by `File ID` and analyzes only the matching rows. A
`Condition` column can be supplied directly or constructed from any annotation
columns:

```yaml
condition_columns: ["Time", "Group"]
condition_template: "{Time}h_{Group}"
```

See [input files](docs/input-files.md) and the complete
[configuration reference](docs/configuration.md).

## Planned comparisons

Comparisons may be generated automatically, written directly in YAML, or read
from a long-format CSV/TSV/TXT design file. A row in the design file gives one
nonzero coefficient:

| ContrastType | Label | Condition | Weight |
|---|---|---|---:|
| pairwise | Treatment_vs_Reference | Treatment | 1 |
| pairwise | Treatment_vs_Reference | Reference | -1 |

The workflow validates zero-sum coefficients and produces a plain-language
contrast guide that is also added to the optional Excel export.

## Time-course analysis

The time-course report starts from the normalized protein-level RDS produced by
the main report. It is intended for independent biological samples, not
repeated measures. Configure the time and group columns and run:

```bash
docker compose run --rm pdtomsstats \
  Rscript scripts/render_timecourse_report.R \
  config/local-my-project-timecourse.yml
```

It performs balanced group-by-time coverage filtering, polynomial maSigPro
regression, explicit group-by-time interaction selection, and Mfuzz soft
clustering of the comparison-minus-reference effect trajectories. See the
[time-course guide](docs/timecourse.md).

## Optional formatted workbook

If the matching Proteome Discoverer hierarchical protein workbook is
available, run after the main report:

```bash
docker compose run --rm pdtomsstats \
  Rscript scripts/export_workbook.R \
  data/my-project/proteins.xlsx \
  results/my-project
```

The exporter uses only R packages, including `openxlsx2` when a Proteome
Discoverer workbook needs compatibility repair. Details are in the
[workbook export guide](docs/workbook-export.md).

## Native installation

Docker is not mandatory. A native installation needs R 4.5, Quarto 1.8, system
compilers, and all CRAN/Bioconductor dependencies:

```bash
Rscript scripts/install_dependencies.R
Rscript scripts/check_environment.R
```

Native OS-specific notes are in [installation.md](docs/installation.md).

## Repository layout

```text
.
├── Dockerfile
├── compose.yaml
├── msstats-psm-report.qmd
├── timecourse-masigpro-mfuzz.qmd
├── config/                 Configuration templates and public example configs
├── data/example/           Small de-identified runnable example
├── R/                      Reusable analysis helpers
├── scripts/                Validation, rendering, export, and setup tools
├── docs/                   User and method documentation
├── tests/                  Lightweight repository and example checks
├── results/                Generated outputs; ignored by Git
└── figures/                Generated figures; ignored by Git
```

## Reproducibility and privacy

- The container pins R 4.5.2, Bioconductor 3.21, and Quarto 1.8.26.
- Random operations use fixed seeds recorded in configuration files.
- Every report saves its parameters and R session information.
- Input data, local configuration files, results, figures, RDS files, and
  workbooks are ignored by Git by default.
- The public example is pseudonymized and explicitly unsuitable for biological
  inference.

## Citation and license

Citation metadata are provided in `CITATION.cff`. Scientific analyses should
also cite MSstats, maSigPro, Mfuzz, Quarto, and enrichment packages used in the
rendered report.

No distribution license has been selected yet. Replace `LICENSE` with the
owner-approved license before publishing the repository publicly.

Maintainers should follow the [GitHub publishing guide](docs/publishing.md)
before sharing the repository. It covers private-first publishing,
collaborator access, releases, GitHub Pages, and the prebuilt container image.
