# Docker guide

Docker isolates the complete analysis environment from the host operating
system. Linux, Windows, and macOS users run the same R, Quarto, system
libraries, and R package set.

For a slower, more detailed introduction written for first-time command-line
users, begin with [Getting started without R programming](getting-started.md).

## Install Docker

- Windows and macOS: install Docker Desktop and enable Docker Compose.
- Linux: install Docker Engine and the Compose plugin. Confirm that the current
  user can run Docker, or use the site-approved privilege method.

Check the installation from a terminal or PowerShell window:

```bash
docker --version
docker compose version
```

## Simplest run

From the repository root, use the launcher. It downloads the public GHCR image
the first time and then opens the guided setup.

macOS or Linux:

```bash
./pdtomsstats
```

Windows PowerShell:

```powershell
.\pdtomsstats.ps1
```

See the [one-command guide](command.md) for file, output, time-course, column
mapping, and custom-figure options.

## Build and validate the image

Maintainers and offline sites can still build locally:

```bash
docker compose build
docker compose run --rm pdtomsstats
```

The second command runs `scripts/check_environment.R` and prints the installed
R, Quarto, Bioconductor, MSstats, maSigPro, Mfuzz, and support-package versions.

The Dockerfile supports `linux/amd64` and `linux/arm64`. Docker Desktop selects
the correct architecture automatically, including Apple Silicon Macs.

The first local build compiles a large scientific R environment and can take a
long time. The launcher normally avoids that build by using the published
multi-platform image.

## Run the example

The following command is identical in Bash, zsh, and PowerShell when written on
one line:

```bash
./pdtomsstats run \
  --config config/example-data.yml \
  --outputs html,timecourse \
  --timecourse-config config/example-data-timecourse.yml \
  --non-interactive
```

The repository is mounted at `/workspace` inside the container. Files written
to `/workspace/results` and `/workspace/figures` are therefore visible in the
host repository.

## Run a project

Keep project data and YAML files somewhere inside the repository so their paths
are available through the mounted `/workspace` directory:

```bash
./pdtomsstats run \
  --config config/local-project.yml \
  --outputs html
```

The original `check_inputs.R`, `run_pipeline.R`, rendering, and export scripts
remain available for advanced use and backward compatibility.

## Resource settings

Large PSM exports can require substantial memory during input and QC steps.
Allocate at least 8 GB to Docker; 12–16 GB is preferable for multi-gigabyte
PSM files. Increase Docker Desktop's memory limit if the process exits with
code 137 or an out-of-memory message.

The image sets BLAS and OpenMP work to one thread for predictable behavior.
`number_of_cores` in the project YAML separately controls the cores passed to
MSstats.

## Rebuild after dependency changes

```bash
docker compose build --no-cache
```

A normal `docker compose build` uses cached package layers and is much faster
when only reports or documentation changed.

## Networks with HTTPS inspection

Some institutional networks replace public HTTPS certificates with a private
certificate authority (CA). If package downloads fail with a certificate error,
export the institution-approved CA certificate in PEM format and pass it as a
BuildKit secret:

```bash
docker build \
  --secret id=corporate_ca,src=/path/to/approved-ca.crt \
  --tag pdtomsstats:0.2.1 .
```

The certificate is available only while R packages are downloaded and is
removed before the image layer is committed. Never add a private CA file to the
repository or Docker build context. Ask local IT for the approved certificate
and export procedure; do not disable TLS verification.

## Open an interactive container shell

```bash
docker compose run --rm pdtomsstats bash
```

## File ownership on Linux

Docker Desktop manages mounted-file ownership automatically. On native Linux,
container outputs may be owned by the container user. If this occurs, run the
service with the host user and a writable temporary home:

```bash
docker compose run --rm --user "$(id -u):$(id -g)" \
  -e HOME=/tmp pdtomsstats \
  Rscript scripts/render_report.R config/local-project.yml
```

## Container limitations

- The bundled image includes `org.Hs.eg.db`. For another organism, either set
  `run_gsea: false` or extend the Dockerfile to install the appropriate
  Bioconductor annotation package.
- Input paths outside the repository are not mounted by default. Copy or mount
  them explicitly rather than embedding host-specific absolute paths in shared
  configuration files.

## Prebuilt GitHub image

Maintainers publish the multi-platform image to GitHub Container Registry by
pushing a version tag. See [the publishing guide](publishing.md). The launcher
uses that public image and falls back to `docker compose build` when needed.

HPC users who have SingularityCE or Apptainer instead of Docker should follow
the [Singularity/Apptainer HPC guide](hpc-singularity.md).
