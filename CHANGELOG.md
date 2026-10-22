# Changelog

## Unreleased

- Added convention-based batch discovery for projects with multiple independent
  analyses. The launcher validates all `<analysis-id>__psm.xlsx` inputs first,
  pairs optional protein/annotation/contrast files, submits one Slurm job per
  analysis, and records the complete batch for status reporting.
- Made batch PSM and protein role suffixes case-insensitive and accepted both
  singular `protein` and plural `proteins`, while rejecting ambiguous pairs.
- Grouped the main and time-course HTML reports and default formatted Excel
  workbook under a `main/` subdirectory of the configured results directory
  and grouped main-analysis CSV/RDS/YAML files under `supporting/`, while
  retaining time-course supporting outputs in `timecourse/` and compatibility
  with legacy analysis objects in the results root.

## 0.2.4 - 2026-10-21

- Moved the time-course dashboard gene symbol into the selected-protein card
  for a four-card row and added gene symbols to protein-level time-course HTML
  and CSV tables.

## 0.2.3 - 2026-10-20

- Render main and time-course Quarto reports from per-job writable staging
  directories so the standardized read-only workflow mount works on HPC.

## 0.2.2 - 2026-10-20

- Preserved logical filesystem paths in the standardized launcher and added
  profile-driven alias binds so Biowulf projects work through either
  `/data/Proteomics_IDSS` or `/vf/users/Proteomics_IDSS` without user-created
  symlinks or environment variables.

## 0.2.1 - 2026-10-20

- Added workbook-derived `GN=` gene symbols to a dedicated card in the
  interactive time-course trajectory dashboard.
- Passed the protein workbook through resolved time-course configuration and
  provenance so gene annotations are reproducible in local and Slurm runs.
- Added support for resolving semicolon-delimited protein accession groups to
  slash-delimited gene symbols without changing statistical model results.

## 0.2.0 - 2026-10-20

- Added standardized `init`, `validate`, `run`, `submit`, `status`, and
  `version` commands without changing the scientific analysis scripts.
- Made `pdtomsstats run` use the execution profile's default mode. The Biowulf
  profile submits a detached Slurm job by default; `--mode local` runs in the
  current allocation and `--mode slurm` explicitly submits.
- Added reusable main/time-course/contrast templates and a Biowulf execution
  profile with pinned Apptainer/SIF settings and group permissions.
- Isolated host home directories with `--containall`, removed inherited HOME
  overrides, and explicitly bound only workflow, project, and job scratch.
- Allowed HTML, Excel, and time-course outputs to run independently; downstream
  outputs reuse the existing main-analysis RDS unless `--with-dependencies` is
  requested.
- Added retained Slurm scripts, job tracking, provenance reporting, launcher
  tests, and standardized-project/HPC documentation.

## 0.1.2 - 2026-10-09

- Retained GitHub workflow definitions in the Docker build context so the
  image's repository-structure validation succeeds during multi-platform
  publishing.

## 0.1.1 - 2026-10-09

- Split the formatted workbook into a protein-only `Proteins` worksheet and a
  complete hierarchical `Peptide` worksheet.
- Extended hierarchy colors through blank cells and included master-protein
  candidates in protein formatting.
- Replaced non-finite numeric Excel errors with explicit `NA`, `Inf`, and
  `-Inf` labels.

## 0.1.0 - 2026-10-09

- Added the generalized PSM and annotation-driven MSstats report.
- Added automatic and explicit contrast configuration.
- Added organism-aware GO Biological Process GSEA.
- Added reusable input validation and render commands.
- Added the generalized hierarchical Excel workbook exporter.
- Added generalized independent-sample maSigPro and Mfuzz time-course analysis.
- Added a multi-architecture Docker environment and Compose commands.
- Added a synthetic-identifier, runnable PSM/time-course example.
- Added documentation, privacy-safe Git defaults, and a lightweight CI check.
- Added a beginner-oriented Docker walkthrough for Windows, macOS, and Linux.
- Added interactive HPC and Slurm instructions for SingularityCE and Apptainer.
- Added private-first GitHub publishing and collaborator instructions.
- Added automated GitHub Pages deployment for the documentation website.
- Added an automated multi-platform GitHub Container Registry release workflow.
