#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 1L || length(args) > 2L) {
  stop(
    "Usage: describe_contrasts.R <contrasts.csv|tsv|txt> [output.csv]",
    call. = FALSE
  )
}

script_argument <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
script_file <- sub("^--file=", "", script_argument[[1]])
repo_root <- normalizePath(
  file.path(dirname(script_file), ".."), winslash = "/", mustWork = TRUE
)

input_file <- normalizePath(args[[1]], winslash = "/", mustWork = TRUE)
default_output <- file.path(dirname(input_file), "msstats_contrast_guide.csv")
output_file <- if (length(args) == 2L) args[[2]] else default_output
if (!grepl("^(/|[A-Za-z]:[/\\\\])", output_file)) {
  output_file <- file.path(getwd(), output_file)
}

source(file.path(repo_root, "R", "contrast-functions.R"))
contrast_table <- read_contrast_file(input_file)
guide <- write_contrast_guide(contrast_table, output_file)

cat("Contrast file:", input_file, "\n")
cat("Contrasts documented:", nrow(guide), "\n")
cat(
  "Guide:",
  normalizePath(output_file, winslash = "/", mustWork = TRUE),
  "\n"
)
