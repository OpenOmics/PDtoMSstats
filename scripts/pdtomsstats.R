#!/usr/bin/env Rscript
# Authors: Subrata Paul and Kevin Cormier

pdt_help <- function() {
  cat(
"PDtoMSstats: one command for MSstats reports, workbooks, and time courses

Usage:
  pdtomsstats                         Start the interactive wizard
  pdtomsstats run [options]           Run with command-line options
  pdtomsstats run --config FILE       Run from an existing YAML configuration
  pdtomsstats help                    Show this help

Minimal examples:
  pdtomsstats run --psm psm.xlsx --annotation annotation.csv --outputs html

  pdtomsstats run --psm psm.xlsx --annotation annotation.csv \\
    --protein-workbook proteins.xlsx --outputs html,excel

  pdtomsstats run --config project.yml --outputs html,excel,timecourse \\
    --protein-workbook proteins.xlsx --time-column TimePoint \\
    --group-column Infection --reference-group Control \\
    --comparison-group LGTV

Common options:
  --psm FILE                         PSM XLS/XLSX/CSV/TSV/TXT file
  --annotation FILE                  Annotation XLS/XLSX/CSV/TSV/TXT file
  --outputs LIST                     html, excel, timecourse, or all
  --output-dir DIR                   Main results directory
  --request NAME                     Filesystem-safe project name
  --label TEXT                       Human-readable report title
  --condition-columns A,B            Annotation columns that define Condition
  --condition-template TEXT          Example: {TimePoint}h_{Infection}
  --contrast-file FILE               Long-format contrast CSV/TSV/TXT
  --protein-workbook FILE            Required for the formatted Excel workbook
  --no-gsea                          Skip human GO enrichment
  --remove-few-measurements          Enable MSstats sparse-feature filtering
  --cores N                          MSstats processing cores
  --de-pvalue-cutoff NUMBER          Adjusted-p cutoff for Excel DE sheets
  --de-log2fc-cutoff NUMBER          Absolute log2FC cutoff for Excel DE sheets
  --maximum-allowed-fold-change N    Excel protein-view ratio limit (default: 100)
  --gsea-pvalue-cutoff NUMBER        GSEA result-table p-value cutoff
  --extra-qmd FILE                   Append a custom QMD fragment; repeatable
  --report-template FILE             Replace the standard main QMD
  --dry-run                          Write resolved configurations without analysis
  --non-interactive                  Fail instead of prompting for missing choices

Column mapping:
  --psm-file-id-column NAME
  --psm-sequence-column NAME
  --psm-charge-column NAME
  --psm-protein-column NAME
  --psm-intensity-column NAME
  --annotation-file-id-column NAME
  --annotation-file-name-column NAME
  --bioreplicate-column NAME
  --condition-column NAME
  --file-name-from-file-id
  --bioreplicate-from-file-id

Time-course options:
  --time-column NAME
  --group-column NAME
  --reference-group VALUE
  --comparison-group VALUE
  --time-unit NUMBER
  --min-replicates N
  --polynomial-degree N
  --spline-df N
  --model-fdr NUMBER
  --limma-interaction-fdr NUMBER
  --coefficient-alpha NUMBER
  --min-r-squared NUMBER
  --min-clusters N
  --max-clusters N
  --timecourse-extra-qmd FILE         Repeatable custom time-course fragment
  --timecourse-template FILE          Replace the standard time-course QMD

Advanced settings remain available in the YAML configuration. Command-line
values override the corresponding YAML values.
")
}

script_argument <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
if (!length(script_argument)) stop("Could not locate the wrapper script.", call. = FALSE)
script_file <- normalizePath(
  sub("^--file=", "", script_argument[[1]]),
  winslash = "/",
  mustWork = TRUE
)
repo_root <- normalizePath(
  file.path(dirname(script_file), ".."), winslash = "/", mustWork = TRUE
)
project_root <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)

required_packages <- c("data.table", "readxl", "yaml")
missing_packages <- required_packages[
  !vapply(required_packages, requireNamespace, logical(1), quietly = TRUE)
]
if (length(missing_packages)) {
  stop(
    "The wrapper requires: ", paste(missing_packages, collapse = ", "),
    ". Use the PDtoMSstats container or install these packages.",
    call. = FALSE
  )
}

source(file.path(repo_root, "R", "input-functions.R"))
source(file.path(repo_root, "R", "wrapper-functions.R"))

raw_args <- commandArgs(trailingOnly = TRUE)
parsed <- pdt_parse_cli(raw_args)
if (identical(parsed$command, "help") || isTRUE(parsed$options$help)) {
  pdt_help()
  quit(save = "no", status = 0L)
}

interactive_allowed <- !isTRUE(parsed$options$non_interactive) &&
  (interactive() || isatty(stdin()))
if (!length(raw_args) && !interactive_allowed) {
  pdt_help()
  quit(save = "no", status = 0L)
}

outputs <- pdt_resolve_outputs(parsed$options, interactive_allowed)
cat("\nPreparing PDtoMSstats run\n")
cat("Requested outputs: ", paste(outputs, collapse = ", "), "\n", sep = "")

prepared_main <- pdt_prepare_main_config(
  parsed$options,
  parsed$provided,
  project_root,
  interactive_allowed = interactive_allowed
)
main_config <- prepared_main$config

if (interactive_allowed &&
    !any(c("gsea", "no_gsea") %in% parsed$provided) &&
    !pdt_is_set(parsed$options$config)) {
  main_config$run_gsea <- pdt_prompt_yes_no(
    "Run human GO Biological Process enrichment", default = TRUE
  )
}

protein_workbook <- parsed$options$protein_workbook
if ("excel" %in% outputs && !pdt_is_set(protein_workbook) && interactive_allowed) {
  protein_workbook <- pdt_prompt(
    "Proteome Discoverer protein workbook for Excel export",
    required = TRUE
  )
}
if ("excel" %in% outputs && !pdt_is_set(protein_workbook)) {
  stop(
    "Excel output requires --protein-workbook for the current formatted workbook.",
    call. = FALSE
  )
}
if (pdt_is_set(protein_workbook)) {
  protein_workbook <- pdt_resolve_path(
    protein_workbook, project_root, must_work = TRUE
  )
}

excel_output <- parsed$options$excel_output
if (pdt_is_set(excel_output)) {
  excel_output <- pdt_resolve_path(excel_output, project_root, must_work = FALSE)
}

timecourse_config <- NULL
if ("timecourse" %in% outputs) {
  timecourse_config <- pdt_prepare_timecourse_config(
    main_config,
    prepared_main$annotation,
    parsed$options,
    parsed$provided,
    project_root,
    interactive_allowed = interactive_allowed
  )
}

dir.create(main_config$output_dir, recursive = TRUE, showWarnings = FALSE)
main_config_file <- pdt_write_config(
  main_config,
  file.path(main_config$output_dir, "pdtomsstats-resolved.yml")
)
timecourse_config_file <- NULL
if (!is.null(timecourse_config)) {
  dir.create(timecourse_config$output_dir, recursive = TRUE, showWarnings = FALSE)
  timecourse_config_file <- pdt_write_config(
    timecourse_config,
    file.path(timecourse_config$output_dir, "pdtomsstats-timecourse-resolved.yml")
  )
}

run_manifest <- list(
  request = main_config$request,
  requested_outputs = outputs,
  main_config = main_config_file,
  timecourse_config = timecourse_config_file,
  protein_workbook = protein_workbook,
  excel_output = excel_output,
  created = format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z")
)
manifest_file <- pdt_write_config(
  run_manifest,
  file.path(main_config$output_dir, "pdtomsstats-run.yml")
)

cat("Resolved main configuration: ", main_config_file, "\n", sep = "")
if (!is.null(timecourse_config_file)) {
  cat("Resolved time-course configuration: ", timecourse_config_file, "\n", sep = "")
}

if (isTRUE(parsed$options$dry_run)) {
  cat("Dry run complete. No analysis was performed.\n")
  quit(save = "no", status = 0L)
}

rscript <- file.path(R.home("bin"), "Rscript")
execution_main_config <- tempfile(pattern = "pdt-main-", fileext = ".yml")
if (!file.copy(main_config_file, execution_main_config, overwrite = TRUE)) {
  stop("Could not prepare the main execution configuration.", call. = FALSE)
}
on.exit(unlink(execution_main_config), add = TRUE)

execution_timecourse_config <- NULL
if (!is.null(timecourse_config_file)) {
  execution_timecourse_config <- tempfile(
    pattern = "pdt-timecourse-", fileext = ".yml"
  )
  if (!file.copy(
    timecourse_config_file, execution_timecourse_config, overwrite = TRUE
  )) {
    stop("Could not prepare the time-course execution configuration.", call. = FALSE)
  }
  on.exit(unlink(execution_timecourse_config), add = TRUE)
}

run_step <- function(label, script, arguments) {
  cat("\n== ", label, " ==\n", sep = "")
  old_working_directory <- setwd(repo_root)
  on.exit(setwd(old_working_directory), add = TRUE)
  status <- system2(rscript, c(file.path("scripts", script), arguments))
  if (!identical(status, 0L)) {
    stop(label, " failed with status ", status, ".", call. = FALSE)
  }
}

run_step("Input validation", "check_inputs.R", execution_main_config)

keep_main_html <- "html" %in% outputs
main_html_name <- if (keep_main_html) {
  paste0(main_config$request, ".html")
} else {
  paste0(main_config$request, "-analysis-intermediate.html")
}
main_html_file <- file.path(main_config$output_dir, main_html_name)
run_step(
  "MSstats analysis",
  "render_report.R",
  c(execution_main_config, main_html_name)
)

timecourse_html_file <- NULL
if ("timecourse" %in% outputs) {
  timecourse_html_name <- paste0(timecourse_config$request, ".html")
  timecourse_html_file <- file.path(
    timecourse_config$output_dir, timecourse_html_name
  )
  run_step(
    "maSigPro, limma-spline, and Mfuzz time-course analysis",
    "render_timecourse_report.R",
    c(execution_timecourse_config, timecourse_html_name)
  )
}

# Run the scientific analyses before the optional formatted workbook. Large
# Proteome Discoverer workbooks can require substantially more memory than the
# reports, and an Excel resource failure should not prevent a requested
# time-course analysis from being produced.
workbook_file <- NULL
if ("excel" %in% outputs) {
  workbook_file <- if (pdt_is_set(excel_output)) {
    excel_output
  } else {
    file.path(
      main_config$output_dir,
      paste0(
        tools::file_path_sans_ext(basename(protein_workbook)),
        "_MSstats.xlsx"
      )
    )
  }
  workbook_job_file <- tempfile(pattern = "pdt-workbook-", fileext = ".yml")
  yaml::write_yaml(
    list(
      protein_file = protein_workbook,
      results_dir = main_config$output_dir,
      output_file = workbook_file,
      maximum_allowed_fold_change = main_config$maximum_allowed_fold_change
    ),
    workbook_job_file
  )
  on.exit(unlink(workbook_job_file), add = TRUE)
  run_step(
    "Formatted Excel workbook",
    "export_workbook.R",
    c("--job", workbook_job_file)
  )
}

if (!keep_main_html && file.exists(main_html_file)) {
  unlink(main_html_file)
  main_html_file <- NULL
}

cat("\nPDtoMSstats completed successfully.\n")
cat("Run manifest: ", manifest_file, "\n", sep = "")
if (!is.null(main_html_file)) cat("HTML report: ", main_html_file, "\n", sep = "")
if (!is.null(workbook_file)) cat("Excel workbook: ", workbook_file, "\n", sep = "")
if (!is.null(timecourse_html_file)) {
  cat("Time-course report: ", timecourse_html_file, "\n", sep = "")
}
