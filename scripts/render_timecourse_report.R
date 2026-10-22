#!/usr/bin/env Rscript
# Author: Subrata Paul

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 1L || length(args) > 2L) {
  stop(
    "Usage: render_timecourse_report.R <config.yml> [output.html]",
    call. = FALSE
  )
}

if (!requireNamespace("yaml", quietly = TRUE)) {
  stop("Install the yaml package before rendering.", call. = FALSE)
}

script_argument <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
script_file <- sub("^--file=", "", script_argument[[1]])
repo_root <- normalizePath(
  file.path(dirname(script_file), ".."), winslash = "/", mustWork = TRUE
)
original_working_directory <- getwd()

config_argument <- args[[1]]
config_file <- if (grepl("^(/|[A-Za-z]:[/\\\\])", config_argument)) {
  config_argument
} else {
  file.path(original_working_directory, config_argument)
}
config_file <- normalizePath(config_file, winslash = "/", mustWork = TRUE)
config <- yaml::read_yaml(config_file)

if (is.null(config$request) || !nzchar(config$request)) {
  stop("The configuration must define request.", call. = FALSE)
}
if (is.null(config$analysis_file) || !nzchar(config$analysis_file)) {
  stop("The configuration must define analysis_file.", call. = FALSE)
}
if (is.null(config$output_dir) || !nzchar(config$output_dir)) {
  config$output_dir <- "results/timecourse-analysis"
}

resolve_repo_path <- function(path) {
  if (grepl("^(/|[A-Za-z]:[/\\\\])", path)) path else file.path(repo_root, path)
}

configured_analysis_file <- resolve_repo_path(config$analysis_file)
analysis_directory <- dirname(configured_analysis_file)
analysis_name <- basename(configured_analysis_file)
legacy_or_supporting_file <- if (basename(analysis_directory) == "supporting") {
  file.path(dirname(analysis_directory), analysis_name)
} else {
  file.path(analysis_directory, "supporting", analysis_name)
}
analysis_candidates <- unique(c(
  configured_analysis_file,
  legacy_or_supporting_file
))
existing_analysis <- analysis_candidates[file.exists(analysis_candidates)]
if (!length(existing_analysis)) {
  stop(
    "Analysis RDS not found. Tried: ",
    paste(analysis_candidates, collapse = ", "),
    call. = FALSE
  )
}
analysis_file <- existing_analysis[[1L]]

output_dir <- resolve_repo_path(config$output_dir)
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
output_dir <- normalizePath(output_dir, winslash = "/", mustWork = TRUE)
analysis_directory <- dirname(
  normalizePath(analysis_file, winslash = "/", mustWork = TRUE)
)
results_root <- if (basename(analysis_directory) == "supporting") {
  dirname(analysis_directory)
} else {
  analysis_directory
}
report_output_dir <- file.path(results_root, "main")
dir.create(report_output_dir, recursive = TRUE, showWarnings = FALSE)
report_output_dir <- normalizePath(
  report_output_dir, winslash = "/", mustWork = TRUE
)

default_output_name <- paste0(
  gsub("[^A-Za-z0-9._-]+", "-", config$request),
  ".html"
)
output_name <- if (length(args) == 2L) basename(args[[2]]) else default_output_name
if (!grepl("[.]html$", output_name, ignore.case = TRUE)) {
  output_name <- paste0(output_name, ".html")
}

quarto <- Sys.which("quarto")
if (!nzchar(quarto)) {
  stop("Quarto was not found on PATH. Install it from https://quarto.org/.", call. = FALSE)
}

source(file.path(repo_root, "R", "render-functions.R"))

has_custom_template <- !is.null(config$report_template) &&
  length(config$report_template) == 1L &&
  !is.na(config$report_template) &&
  nzchar(config$report_template)
report_file <- if (has_custom_template) {
  normalizePath(
    resolve_repo_path(config$report_template),
    winslash = "/",
    mustWork = TRUE
  )
} else {
  file.path(repo_root, "timecourse-masigpro-mfuzz.qmd")
}
report_source_directory <- dirname(report_file)
render_workspace <- pdt_stage_quarto_report(
  report_file,
  repo_root,
  prefix = "pdtomsstats-timecourse-render-"
)
on.exit(unlink(render_workspace$directory, recursive = TRUE, force = TRUE), add = TRUE)
report_file <- render_workspace$report
old_working_directory <- setwd(render_workspace$directory)
on.exit(setwd(old_working_directory), add = TRUE)
Sys.setenv(PDTOMSSTATS_REPORT_SOURCE_DIR = report_source_directory)

quarto_config <- tempfile(pattern = "timecourse-params-", fileext = ".yml")
config$analysis_file <- analysis_file
yaml::write_yaml(config, quarto_config)
on.exit(unlink(quarto_config), add = TRUE)

cat("Rendering", output_name, "...\n")
render_status <- system2(
  quarto,
  c(
    "render", basename(report_file),
    "--execute-params", shQuote(quarto_config),
    "--output", output_name
  )
)
if (!identical(render_status, 0L)) {
  stop("Quarto render failed with status ", render_status, ".", call. = FALSE)
}

rendered_file <- file.path(render_workspace$directory, output_name)
if (!file.exists(rendered_file)) {
  stop(
    "Quarto finished but the expected HTML file was not found: ",
    rendered_file,
    call. = FALSE
  )
}

final_file <- file.path(report_output_dir, output_name)
if (normalizePath(rendered_file, winslash = "/", mustWork = TRUE) !=
    normalizePath(final_file, winslash = "/", mustWork = FALSE)) {
  copied <- file.copy(rendered_file, final_file, overwrite = TRUE)
  if (!copied) {
    stop("Could not copy the rendered report to ", final_file, call. = FALSE)
  }
  unlink(rendered_file)
}

cat("Report:", normalizePath(final_file, winslash = "/", mustWork = TRUE), "\n")
cat("Results:", output_dir, "\n")
