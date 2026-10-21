#!/usr/bin/env Rscript

script_argument <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
script_file <- sub("^--file=", "", script_argument[[1]])
repo_root <- normalizePath(
  file.path(dirname(script_file), ".."), winslash = "/", mustWork = TRUE
)

required_files <- c(
  "README.md",
  "VERSION",
  "pdtomsstats",
  "pdtomsstats.ps1",
  "Dockerfile",
  "compose.yaml",
  "DESCRIPTION",
  "LICENSE",
  "msstats-psm-report.qmd",
  "timecourse-masigpro-mfuzz.qmd",
  "config/example.yml",
  "config/example-data.yml",
  "config/example-data-timecourse.yml",
  "config/timecourse-example.yml",
  "config/profiles/biowulf.yml",
  "config/templates/main.yml",
  "config/templates/timecourse.yml",
  "config/templates/contrasts.tsv",
  "data/example/psm.csv",
  "data/example/annotation.csv",
  "data/example/contrasts.tsv",
  "data/example/SHA256SUMS",
  "docs/docker.md",
  "docs/command.md",
  "docs/example.md",
  "docs/getting-started.md",
  "docs/hpc-singularity.md",
  "docs/index.md",
  "docs/installation.md",
  "docs/standardized-projects.md",
  "docs/timecourse.md",
  "docs/_quarto.yml",
  "docs/styles.css",
  "templates/extra-figures-example.qmd",
  ".github/workflows/pages.yml",
  ".github/workflows/publish-container.yml",
  "R/dependencies.R",
  "R/input-validation.R",
  "R/wrapper-functions.R",
  "R/input-functions.R",
  "R/contrast-functions.R",
  "R/qc-helper-functions.R",
  "R/pathway-analysis-functions.R",
  "R/render-functions.R",
  "scripts/check_inputs.R",
  "scripts/describe_contrasts.R",
  "scripts/install_dependencies.R",
  "scripts/check_environment.R",
  "scripts/pdtomsstats.R",
  "scripts/run_pipeline.R",
  "scripts/render_report.R",
  "scripts/render_timecourse_report.R",
  "scripts/export_workbook.R",
  "scripts/export_msstats_workbook.R",
  "scripts/calculate_unnormalized_msstats_protein_abundance.R",
  "tests/test_workbook_dimensions.R",
  "tests/test_cli.sh"
)
missing_files <- required_files[!file.exists(file.path(repo_root, required_files))]
if (length(missing_files)) {
  stop("Missing repository file(s): ", paste(missing_files, collapse = ", "), call. = FALSE)
}

version <- trimws(readLines(file.path(repo_root, "VERSION"), warn = FALSE)[[1]])
description <- read.dcf(file.path(repo_root, "DESCRIPTION"))
if (!identical(version, unname(description[[1, "Version"]]))) {
  stop("VERSION and DESCRIPTION Version must match.", call. = FALSE)
}

yaml_files <- c(
  "config/profiles/biowulf.yml",
  "config/templates/main.yml",
  "config/templates/timecourse.yml"
)
for (yaml_file in yaml_files) {
  parsed_yaml <- yaml::read_yaml(file.path(repo_root, yaml_file))
  if (!is.list(parsed_yaml)) {
    stop("Expected a YAML mapping in ", yaml_file, ".", call. = FALSE)
  }
}
biowulf_profile <- yaml::read_yaml(
  file.path(repo_root, "config/profiles/biowulf.yml")
)
if (!isTRUE(biowulf_profile$containall) ||
    !grepl(paste0("_", version, "[.]sif$"), biowulf_profile$image)) {
  stop("The Biowulf profile must isolate HOME and match VERSION.", call. = FALSE)
}

launcher <- readLines(file.path(repo_root, "pdtomsstats"), warn = FALSE)
for (text in c("--containall", "init", "validate", "submit", "status")) {
  if (!any(grepl(text, launcher, fixed = TRUE))) {
    stop("The standardized launcher is missing expected text: ", text, call. = FALSE)
  }
}

r_files <- list.files(repo_root, pattern = "[.]R$", recursive = TRUE, full.names = TRUE)
for (file in r_files) {
  parse(file = file)
}

source(file.path(repo_root, "R", "render-functions.R"))
staged_report <- pdt_stage_quarto_report(
  file.path(repo_root, "msstats-psm-report.qmd"),
  repo_root,
  prefix = "pdtomsstats-test-render-"
)
if (!file.exists(staged_report$report) || file.access(staged_report$report, 2L) != 0L ||
    !file.exists(file.path(staged_report$directory, "R", "input-functions.R")) ||
    !file.exists(file.path(staged_report$directory, "assets", "style.css"))) {
  stop("The writable Quarto staging directory is incomplete.", call. = FALSE)
}
unlink(staged_report$directory, recursive = TRUE, force = TRUE)

qmd <- readLines(file.path(repo_root, "msstats-psm-report.qmd"), warn = FALSE)
required_qmd_text <- c(
  "pathway-analysis-functions.R",
  "qc-helper-functions.R",
  "msstats_workbook_export_objects.rds",
  "normalize_psm_columns(params)",
  "additional-report-sections"
)
for (text in required_qmd_text) {
  if (!any(grepl(text, qmd, fixed = TRUE))) {
    stop("The report is missing expected text: ", text, call. = FALSE)
  }
}

timecourse_qmd <- readLines(
  file.path(repo_root, "timecourse-masigpro-mfuzz.qmd"),
  warn = FALSE
)
required_timecourse_text <- c(
  "stats::poly",
  "maSigPro::p.vector",
  "maSigPro::T.fit",
  "limma::lmFit",
  "limma::eBayes",
  "limma_interaction_fdr",
  "timecourse_combined_significant_proteins.csv",
  "combined_interpretation_results",
  "TrajectorySummary",
  "SignificanceCategory",
  "mfuzz_method_parameter_comparison.csv",
  "fit_method_mfuzz",
  "Column meanings and interpretation",
  "describe_timecourse_column",
  "html-math-method: mathml",
  "t = \\frac{\\text{hour}",
  "\\Delta_t = \\overline{y}",
  "Detailed methods",
  "additional-timecourse-sections",
  "prepare-trajectory-explorer",
  "trajectory-explorer-data",
  "trajectory-dashboard-script",
  "trajectory-protein-search",
  "Gene symbol (GN)",
  "match_pd_gene_symbols",
  "add_gene_symbols",
  ".data$GeneSymbol",
  "opts_knit$set(root.dir = report_dir)",
  "renderChart",
  "trajectory-card-grid"
)
for (text in required_timecourse_text) {
  if (!any(grepl(text, timecourse_qmd, fixed = TRUE))) {
    stop("The time-course report is missing expected text: ", text, call. = FALSE)
  }
}

if (any(grepl("```{ojs}", timecourse_qmd, fixed = TRUE)) ||
    any(grepl("ojs_define", timecourse_qmd, fixed = TRUE))) {
  stop(
    "The standalone time-course report must not use OJS because OJS is disabled for file:// URLs.",
    call. = FALSE
  )
}

if (any(grepl("LGTV", timecourse_qmd, fixed = TRUE))) {
  stop("The generalized time-course report still contains an LGTV-specific label.", call. = FALSE)
}
if (sum(grepl("^column_guide\\(", timecourse_qmd)) < 13L) {
  stop(
    "Every displayed time-course table must have a column-guide dropdown.",
    call. = FALSE
  )
}
if (any(grepl("\\[", timecourse_qmd, fixed = TRUE)) ||
    any(grepl("\\(", timecourse_qmd, fixed = TRUE))) {
  stop(
    "The time-course report uses unsupported backslash-delimited math.",
    call. = FALSE
  )
}

dockerfile <- readLines(file.path(repo_root, "Dockerfile"), warn = FALSE)
required_docker_text <- c(
  "rocker/r-ver:${R_VERSION}",
  "TARGETARCH",
  "quarto-${QUARTO_VERSION}-linux-${quarto_arch}.deb",
  "scripts/install_dependencies.R",
  "scripts/check_environment.R"
)
for (text in required_docker_text) {
  if (!any(grepl(text, dockerfile, fixed = TRUE))) {
    stop("The Dockerfile is missing expected text: ", text, call. = FALSE)
  }
}

dockerignore <- readLines(file.path(repo_root, ".dockerignore"), warn = FALSE)
if (any(trimws(dockerignore) == ".github")) {
  stop(
    ".dockerignore must retain .github because container structure checks ",
    "validate the published workflow files.",
    call. = FALSE
  )
}

export_script <- readLines(
  file.path(repo_root, "scripts/export_msstats_workbook.R"),
  warn = FALSE
)
required_export_text <- c(
  "protein_candidate_rows",
  "prepare_excel_data",
  "repair_worksheet_dimensions(wb",
  "protein_sheet <- \"Proteins\"",
  "main_sheet <- \"Peptide\"",
  "topLeftCell=\\\"E2\\\"",
  "wb$worksheets[[main_sheet_index]]$sheetViews <-",
  "wb$worksheets[[main_sheet_index]]$freezePane <- main_freeze_pane"
)
for (text in required_export_text) {
  if (!any(grepl(text, export_script, fixed = TRUE))) {
    stop("The workbook exporter is missing expected text: ", text, call. = FALSE)
  }
}

order_line <- grep("worksheetOrder(wb) <-", export_script, fixed = TRUE)
main_index_lines <- grep(
  "main_sheet_index <- match(main_sheet, names(wb))",
  export_script,
  fixed = TRUE
)
pane_line <- grep(
  "wb$worksheets[[main_sheet_index]]$sheetViews <-",
  export_script,
  fixed = TRUE
)
if (!any(main_index_lines > order_line & main_index_lines < pane_line)) {
  stop(
    "The main worksheet index must be refreshed after worksheets are reordered.",
    call. = FALSE
  )
}

cat("Repository structure and R syntax: PASS\n")
