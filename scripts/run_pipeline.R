#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 1L || length(args) > 2L) {
  stop(
    paste(
      "Usage: run_pipeline.R <main-config.yml>",
      "[timecourse-config.yml]"
    ),
    call. = FALSE
  )
}

script_argument <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
script_file <- sub("^--file=", "", script_argument[[1]])
repo_root <- normalizePath(
  file.path(dirname(script_file), ".."), winslash = "/", mustWork = TRUE
)
old_working_directory <- setwd(repo_root)
on.exit(setwd(old_working_directory), add = TRUE)

rscript <- file.path(R.home("bin"), "Rscript")
run_step <- function(label, script, arguments) {
  cat("\n==", label, "==\n")
  status <- system2(rscript, c(script, arguments))
  if (!identical(status, 0L)) {
    stop(label, " failed with status ", status, ".", call. = FALSE)
  }
}

run_step("Input validation", "scripts/check_inputs.R", args[[1]])
run_step("MSstats report", "scripts/render_report.R", args[[1]])

if (length(args) == 2L) {
  run_step(
    "maSigPro and Mfuzz time-course report",
    "scripts/render_timecourse_report.R",
    args[[2]]
  )
}

cat("\nPDtoMSstats pipeline completed successfully.\n")
