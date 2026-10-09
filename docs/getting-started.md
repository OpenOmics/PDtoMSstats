# Getting started without R programming

This guide is for someone who wants to run PDtoMSstats but does not routinely
write scripts. Most steps involve copying files, changing a few lines in a
text file, and pasting a command.

## What Docker does

Docker provides R, Quarto, MSstats, maSigPro, Mfuzz, and the other required
packages in one controlled environment. You do not install those programs or
R packages separately.

Your input and output files remain in the PDtoMSstats folder on your computer.
They are not uploaded by Docker.

## 1. Install Docker

### Windows or macOS

1. Install Docker Desktop from the official Docker website.
2. Start Docker Desktop.
3. Wait until Docker Desktop says the engine is running.

On Windows, use the WSL 2 backend when Docker Desktop offers that choice. The
default Docker Desktop settings are normally sufficient.

### Linux

Install Docker Engine and the Docker Compose plugin using the instructions for
your Linux distribution. Confirm that your account is allowed to run Docker.

### Confirm the installation

Open PowerShell or Windows Terminal on Windows, or Terminal on macOS/Linux,
and run:

```bash
docker --version
docker compose version
```

Both commands should print a version. If they do not, start Docker Desktop or
ask your local IT support to finish the Docker installation.

## 2. Download PDtoMSstats

Choose either method below.

### Method A: Download a ZIP file

1. Open the PDtoMSstats repository on GitHub.
2. Select **Code**, then **Download ZIP**.
3. Extract the ZIP file to a normal working folder.

Do not run the workflow from inside the compressed ZIP file.

### Method B: Clone with Git

If Git is installed, run:

```bash
git clone https://github.com/OWNER/PDtoMSstats.git
cd PDtoMSstats
```

Replace `OWNER` with the GitHub user or organization that hosts the repository.

## 3. Open a terminal in the PDtoMSstats folder

The terminal must be in the folder containing `compose.yaml`, `Dockerfile`,
`README.md`, `data`, and `config`.

- Windows: open the folder in File Explorer, right-click an empty area, and
  choose **Open in Terminal**. On older Windows versions, enter `powershell` in
  the File Explorer address bar.
- macOS: open Terminal, type `cd ` including the space, drag the PDtoMSstats
  folder into the Terminal window, and press Return.
- Linux: use the file manager's **Open in Terminal** option, or use `cd`.

Check that you are in the correct folder:

```bash
docker compose config
```

This should display the Docker configuration without an error.

## 4. Build the analysis environment

Run:

```bash
docker compose build
```

The first build downloads R and installs many scientific packages, so it can
take a while. Later builds reuse a cache and are usually much faster. Keep
Docker running and do not close the terminal during the first build.

Check the completed environment:

```bash
docker compose run --rm pdtomsstats
```

The command should finish by reporting that the environment check passed.

## 5. Run the demonstration

Start with the de-identified example before using private data:

```bash
docker compose run --rm pdtomsstats Rscript scripts/run_pipeline.R config/example-data.yml
```

Successful completion ends with:

```text
PDtoMSstats pipeline completed successfully.
```

Open `results/example/deidentified-example.html` in a web browser. The CSV
tables are in the same folder, and the separate figures are under
`figures/example`.

The example contains synthetic identifiers and must not be used for biological
interpretation.

## 6. Add a project

Create a folder such as:

```text
data/my-project/
```

Copy these files into it:

1. the PSM table exported from Proteome Discoverer;
2. the sample annotation table;
3. optionally, the Proteome Discoverer protein workbook for the formatted
   Excel export;
4. optionally, a contrast CSV, TSV, or TXT file.

Private files under `data` are ignored by Git. Do not force-add them to GitHub.

### Required column names

The PSM table normally needs:

- `File ID`
- `Annotated Sequence`
- `Charge`
- `Master Protein Accessions`
- `Quan Value`

The annotation table normally needs:

- `File Name`
- `File ID`
- `BioReplicate`
- either `Condition`, or the columns that will be combined to create it

`File ID` must match exactly between the PSM and annotation tables. The
annotation may contain extra rows; only rows corresponding to the selected PSM
file are used.

## 7. Make a project configuration

Copy the supplied template.

Windows PowerShell:

```powershell
Copy-Item config/example.yml config/local-my-project.yml
```

macOS or Linux:

```bash
cp config/example.yml config/local-my-project.yml
```

Open `config/local-my-project.yml` in a plain-text editor such as Visual Studio
Code, Notepad, Notepad++, or TextEdit in plain-text mode.

At minimum, change these values:

```yaml
request: "my-project"
report_label: "My project"

psm_file: "data/my-project/my-PSM-file.xlsx"
psm_sheet: "PSMs"
annotation_file: "data/my-project/my-annotation-file.xlsx"
annotation_sheet: 1

output_dir: "results/my-project"
figures_dir: "figures/my-project"
```

Use forward slashes in configuration paths, including on Windows. Paths are
relative to the PDtoMSstats folder. Keep the spaces and indentation shown in
the template; YAML uses indentation to organize settings.

If the annotation already has a `Condition` column, leave these settings as:

```yaml
condition_columns: null
condition_template: null
```

To create `Condition` from annotation columns, use their exact names. For
example:

```yaml
condition_columns: ["Time", "Group"]
condition_template: "{Time}h_{Group}"
```

This creates values such as `24h_Control` and `24h_Treatment`.

For nonhuman data, set `run_gsea: false` unless the Docker image contains the
correct organism annotation package.

## 8. Check the inputs before running

Run:

```bash
docker compose run --rm pdtomsstats Rscript scripts/check_inputs.R config/local-my-project.yml
```

Continue only when the final line says `Input check: PASS`. If it fails, read
the first error carefully. The most common causes are an incorrect filename,
worksheet name, column name, or unmatched `File ID`.

## 9. Run the main MSstats analysis

```bash
docker compose run --rm pdtomsstats Rscript scripts/run_pipeline.R config/local-my-project.yml
```

This runs validation, quality control, MSstats summarization and comparisons,
pathway analysis when enabled, and the HTML report. It does not run the
time-course stage unless a second configuration file is supplied.

The main outputs appear in the configured `results/my-project` folder:

- a self-contained HTML report;
- `msstats_all_group_comparisons.csv`;
- one CSV per planned comparison;
- a plain-language contrast guide;
- power and GSEA tables when applicable;
- an RDS object used by optional downstream stages.

Figures also appear in the configured `figures/my-project` folder.

## 10. Optional formatted Excel workbook

If a matching Proteome Discoverer hierarchical protein workbook is available,
run this after the main report:

```bash
docker compose run --rm pdtomsstats Rscript scripts/export_workbook.R data/my-project/my-protein-file.xlsx results/my-project
```

The formatted workbook is saved in `results/my-project`. The source workbook
is not changed. More detail is available in
[the workbook export guide](workbook-export.md).

## 11. Optional time-course analysis

Time-course analysis is appropriate only when the study design and sample
independence assumptions are suitable. Copy and edit
`config/timecourse-example.yml`, then run:

```bash
docker compose run --rm pdtomsstats Rscript scripts/render_timecourse_report.R config/local-my-project-timecourse.yml
```

See [the time-course guide](timecourse.md) before interpreting these results.

## Updating PDtoMSstats

For a Git clone:

```bash
git pull
docker compose build
```

For a ZIP download, download the new release ZIP and keep private data and
results outside the old extracted folder until they are copied safely.

## Common problems

### Docker command not found

Docker Desktop is not installed, is not running, or the terminal was opened
before installation completed. Start Docker Desktop and open a new terminal.

### No configuration file found

The terminal is probably not in the PDtoMSstats folder. Return to step 3.

### Input file not found

Check spelling, capitalization, the file extension, and the relative path in
the YAML file. Use `/`, not `\`, in YAML paths.

### The process exits with code 137

Docker ran out of memory. Increase the memory available to Docker Desktop.
Eight GB is the minimum recommendation; 12–16 GB is preferable for large PSM
tables.

### Windows cannot share the folder

Move the repository to a normal local folder, not a restricted network drive,
and allow Docker Desktop to access that location. Institutional computers may
require help from IT.

### Linux outputs belong to root

Follow the host-user command in [the Docker guide](docker.md#file-ownership-on-linux).

## Getting help

When reporting a problem, include:

- the exact command used;
- the complete error message;
- the operating system;
- the Docker version;
- the PSM and annotation worksheet and column names.

Never post identifiable or unpublished project data in a public GitHub issue.

For an HPC system that provides SingularityCE or Apptainer instead of Docker,
see the [HPC guide](hpc-singularity.md).
