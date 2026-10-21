#!/usr/bin/env Rscript
# Authors: Subrata Paul and Kevin Cormier

args <- commandArgs(trailingOnly = TRUE)
job_mode <- length(args) == 2L && identical(args[[1]], "--job")
if (!job_mode && (length(args) < 2L || length(args) > 3L)) {
  stop(
    paste(
      "Usage: export_workbook.R <protein.xlsx> <results_dir> [output.xlsx]",
      "or export_workbook.R --job <job.yml>"
    ),
    call. = FALSE
  )
}

script_argument <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
script_file <- sub("^--file=", "", script_argument[[1]])
repo_root <- normalizePath(
  file.path(dirname(script_file), ".."), winslash = "/", mustWork = TRUE
)

resolve_path <- function(path, must_work = TRUE) {
  candidate <- if (grepl("^(/|[A-Za-z]:[/\\\\])", path)) {
    path
  } else {
    file.path(repo_root, path)
  }
  normalizePath(candidate, winslash = "/", mustWork = must_work)
}

if (job_mode) {
  if (!requireNamespace("yaml", quietly = TRUE)) {
    stop("Install the yaml package to use --job.", call. = FALSE)
  }
  job_file <- resolve_path(args[[2]])
  job <- yaml::read_yaml(job_file)
  required_job_values <- c("protein_file", "results_dir")
  missing_job_values <- required_job_values[
    !vapply(required_job_values, function(name) {
      value <- job[[name]]
      !is.null(value) && length(value) == 1L && !is.na(value) && nzchar(value)
    }, logical(1))
  ]
  if (length(missing_job_values)) {
    stop(
      "Workbook job is missing: ", paste(missing_job_values, collapse = ", "),
      call. = FALSE
    )
  }
  protein_file <- resolve_path(job$protein_file)
  results_dir <- resolve_path(job$results_dir)
} else {
  protein_file <- resolve_path(args[[1]])
  results_dir <- resolve_path(args[[2]])
}
objects_file <- file.path(results_dir, "msstats_workbook_export_objects.rds")
if (!file.exists(objects_file)) {
  stop(
    "Missing ", objects_file, ". Render the report before exporting the workbook.",
    call. = FALSE
  )
}

unnormalized_file <- file.path(results_dir, "msstats_unnormalized_protein_level.rds")
default_output <- file.path(
  results_dir, "main",
  paste0(tools::file_path_sans_ext(basename(protein_file)), "_MSstats.xlsx")
)
output_file <- if (job_mode && !is.null(job$output_file) &&
                   length(job$output_file) == 1L && !is.na(job$output_file) &&
                   nzchar(job$output_file)) {
  resolve_path(job$output_file, must_work = FALSE)
} else if (!job_mode && length(args) == 3L) {
  resolve_path(args[[3]], must_work = FALSE)
} else {
  default_output
}
dir.create(dirname(output_file), recursive = TRUE, showWarnings = FALSE)

calculate_script <- file.path("scripts", "calculate_unnormalized_msstats_protein_abundance.R")
export_script <- file.path("scripts", "export_msstats_workbook.R")

# Run child scripts from the repository root. Relative script paths avoid shell
# quoting failures when the repository's parent directory contains both spaces
# and apostrophes.
old_working_directory <- setwd(repo_root)
on.exit(setwd(old_working_directory), add = TRUE)

source(calculate_script)
calculate_unnormalized_msstats_protein_abundance(objects_file, unnormalized_file)

source(export_script)
export_msstats_workbook(
  protein_file, objects_file, results_dir, output_file,
  maximum_allowed_fold_change = if (job_mode) job$maximum_allowed_fold_change else NULL
)

cat("Workbook:", normalizePath(output_file, winslash = "/", mustWork = TRUE), "\n")
