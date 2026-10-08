#!/usr/bin/env Rscript

script_argument <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
script_file <- sub("^--file=", "", script_argument[[1]])
repo_root <- normalizePath(
  file.path(dirname(script_file), ".."), winslash = "/", mustWork = TRUE
)

required_files <- c(
  "README.md",
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
  "data/example/psm.csv",
  "data/example/annotation.csv",
  "data/example/contrasts.tsv",
  "data/example/SHA256SUMS",
  "docs/docker.md",
  "docs/example.md",
  "docs/installation.md",
  "docs/timecourse.md",
  "R/dependencies.R",
  "R/input-validation.R",
  "R/input-functions.R",
  "R/contrast-functions.R",
  "R/qc-helper-functions.R",
  "R/pathway-analysis-functions.R",
  "scripts/check_inputs.R",
  "scripts/describe_contrasts.R",
  "scripts/install_dependencies.R",
  "scripts/check_environment.R",
  "scripts/run_pipeline.R",
  "scripts/render_report.R",
  "scripts/render_timecourse_report.R",
  "scripts/export_workbook.R",
  "scripts/export_msstats_workbook.R",
  "scripts/calculate_unnormalized_msstats_protein_abundance.R"
)
missing_files <- required_files[!file.exists(file.path(repo_root, required_files))]
if (length(missing_files)) {
  stop("Missing repository file(s): ", paste(missing_files, collapse = ", "), call. = FALSE)
}

r_files <- list.files(repo_root, pattern = "[.]R$", recursive = TRUE, full.names = TRUE)
for (file in r_files) {
  parse(file = file)
}

qmd <- readLines(file.path(repo_root, "msstats-psm-report.qmd"), warn = FALSE)
required_qmd_text <- c(
  "pathway-analysis-functions.R",
  "qc-helper-functions.R",
  "msstats_workbook_export_objects.rds"
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
  "maSigPro::make.design.matrix",
  "maSigPro::p.vector",
  "maSigPro::T.fit",
  "Mfuzz::mestimate",
  "Mfuzz::Dmin",
  "Mfuzz::cselection",
  "Mfuzz::mfuzz",
  "Detailed methods",
  "timecourse_group_difference_effects.csv"
)
for (text in required_timecourse_text) {
  if (!any(grepl(text, timecourse_qmd, fixed = TRUE))) {
    stop("The time-course report is missing expected text: ", text, call. = FALSE)
  }
}

if (any(grepl("LGTV", timecourse_qmd, fixed = TRUE))) {
  stop("The generalized time-course report still contains an LGTV-specific label.", call. = FALSE)
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

export_script <- readLines(
  file.path(repo_root, "scripts/export_msstats_workbook.R"),
  warn = FALSE
)
required_export_text <- c(
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
