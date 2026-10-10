# Changelog

## Unreleased

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
