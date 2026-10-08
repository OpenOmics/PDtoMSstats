#!/usr/bin/env Rscript

script_argument <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
script_file <- sub("^--file=", "", script_argument[[1]])
repo_root <- normalizePath(
  file.path(dirname(script_file), ".."), winslash = "/", mustWork = TRUE
)

source(file.path(repo_root, "R", "input-functions.R"))

annotation <- data.frame(
  Time = c(12, 24),
  Group = c("Reference", "Treatment"),
  stringsAsFactors = FALSE
)

stopifnot(identical(
  make_condition(
    annotation,
    condition_columns = c("Time", "Group"),
    condition_template = "{Time}h_{Group}"
  ),
  c("12h_Reference", "24h_Treatment")
))

stopifnot(identical(
  make_condition(
    annotation,
    condition_columns = c("Time", "Group"),
    condition_separator = "_"
  ),
  c("12_Reference", "24_Treatment")
))

input_file <- tempfile(fileext = ".tsv")
on.exit(unlink(input_file), add = TRUE)
data.table::fwrite(annotation, input_file, sep = "\t")
loaded <- read_input_table(input_file)
stopifnot(identical(names(loaded), names(annotation)), nrow(loaded) == 2L)

cat("Input functions: PASS\n")
