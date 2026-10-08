#!/usr/bin/env Rscript

calculate_unnormalized_msstats_protein_abundance <- function(input_file, output_file) {
input_file <- normalizePath(input_file, winslash = "/", mustWork = TRUE)
objects <- readRDS(input_file)
if (!"msstats_input" %in% names(objects)) {
  stop("The input RDS does not contain msstats_input.", call. = FALSE)
}

settings <- objects$analysis_settings
summary_method <- if (!is.null(settings$summary_method)) {
  settings$summary_method
} else {
  "TMP"
}
number_of_cores <- if (!is.null(settings$number_of_cores)) {
  settings$number_of_cores
} else {
  1
}

processed_unnormalized <- MSstats::dataProcess(
  raw = objects$msstats_input,
  logTrans = 2,
  normalization = FALSE,
  summaryMethod = summary_method,
  MBimpute = FALSE,
  use_log_file = FALSE,
  verbose = FALSE,
  numberOfCores = number_of_cores
)

protein_level <- processed_unnormalized[["ProteinLevelData"]]
if (is.null(protein_level) || nrow(protein_level) == 0L) {
  stop("MSstats did not return unnormalized ProteinLevelData.", call. = FALSE)
}

saveRDS(protein_level, output_file)
cat(
  "Saved", nrow(protein_level),
  "unnormalized, non-imputed protein/run rows to", output_file, "\n"
)
invisible(output_file)
}

if (sys.nframe() == 0L) {
  args <- commandArgs(trailingOnly = TRUE)
  if (length(args) != 2L) {
    stop(
      "Usage: calculate_unnormalized_msstats_protein_abundance.R <msstats_objects.rds> <output.rds>",
      call. = FALSE
    )
  }
  calculate_unnormalized_msstats_protein_abundance(args[[1]], args[[2]])
}
