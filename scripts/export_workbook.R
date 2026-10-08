#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 2L || length(args) > 3L) {
  stop(
    "Usage: export_workbook.R <protein.xlsx> <results_dir> [output.xlsx]",
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

protein_file <- resolve_path(args[[1]])
results_dir <- resolve_path(args[[2]])
objects_file <- file.path(results_dir, "msstats_workbook_export_objects.rds")
if (!file.exists(objects_file)) {
  stop(
    "Missing ", objects_file, ". Render the report before exporting the workbook.",
    call. = FALSE
  )
}

unnormalized_file <- file.path(results_dir, "msstats_unnormalized_protein_level.rds")
default_output <- file.path(
  results_dir,
  paste0(tools::file_path_sans_ext(basename(protein_file)), "_MSstats.xlsx")
)
output_file <- if (length(args) == 3L) resolve_path(args[[3]], must_work = FALSE) else default_output

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
  protein_file, objects_file, results_dir, output_file
)

cat("Workbook:", normalizePath(output_file, winslash = "/", mustWork = TRUE), "\n")
