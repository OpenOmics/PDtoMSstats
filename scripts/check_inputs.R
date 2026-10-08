#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 1L) {
  stop("Usage: check_inputs.R <config.yml>", call. = FALSE)
}

script_argument <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
script_file <- sub("^--file=", "", script_argument[[1]])
repo_root <- normalizePath(
  file.path(dirname(script_file), ".."), winslash = "/", mustWork = TRUE
)

config_argument <- args[[1]]
config_file <- if (grepl("^(/|[A-Za-z]:[/\\\\])", config_argument)) {
  config_argument
} else {
  file.path(getwd(), config_argument)
}

source(file.path(repo_root, "R", "input-validation.R"))
check_msstats_inputs(config_file, repo_root, verbose = TRUE)
