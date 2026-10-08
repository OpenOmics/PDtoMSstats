#!/usr/bin/env Rscript

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

analysis_file <- resolve_repo_path(config$analysis_file)
if (!file.exists(analysis_file)) {
  stop("Analysis RDS not found: ", analysis_file, call. = FALSE)
}

output_dir <- resolve_repo_path(config$output_dir)
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
output_dir <- normalizePath(output_dir, winslash = "/", mustWork = TRUE)

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

report_file <- file.path(repo_root, "timecourse-masigpro-mfuzz.qmd")
old_working_directory <- setwd(repo_root)
on.exit(setwd(old_working_directory), add = TRUE)

quarto_config <- tempfile(pattern = "timecourse-params-", fileext = ".yml")
if (!file.copy(config_file, quarto_config, overwrite = TRUE)) {
  stop("Could not prepare the temporary Quarto parameter file.", call. = FALSE)
}
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

rendered_file <- file.path(repo_root, output_name)
if (!file.exists(rendered_file)) {
  stop(
    "Quarto finished but the expected HTML file was not found: ",
    rendered_file,
    call. = FALSE
  )
}

final_file <- file.path(output_dir, output_name)
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
