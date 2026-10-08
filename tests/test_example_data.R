#!/usr/bin/env Rscript

script_argument <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
script_file <- sub("^--file=", "", script_argument[[1]])
repo_root <- normalizePath(
  file.path(dirname(script_file), ".."), winslash = "/", mustWork = TRUE
)
example_dir <- file.path(repo_root, "data", "example")

psm_file <- file.path(example_dir, "psm.csv")
annotation_file <- file.path(example_dir, "annotation.csv")
contrast_file <- file.path(example_dir, "contrasts.tsv")
stopifnot(file.exists(psm_file, annotation_file, contrast_file))

psm <- utils::read.csv(psm_file, check.names = FALSE)
annotation <- utils::read.csv(annotation_file, check.names = FALSE)
contrasts <- utils::read.delim(contrast_file, check.names = FALSE)

stopifnot(
  nrow(psm) > 1000L,
  length(unique(psm[["File ID"]])) == 60L,
  length(unique(psm[["Master Protein Accessions"]])) >= 20L,
  all(grepl("^RUN[0-9]{3}$", psm[["File ID"]])),
  all(grepl("^PROT[0-9]{4}$", psm[["Master Protein Accessions"]])),
  all(grepl("^PEPTIDE[0-9]{6}$", psm[["Annotated Sequence"]])),
  all(is.finite(psm[["Quan Value"]]) & psm[["Quan Value"]] > 0),
  !anyDuplicated(annotation[["File ID"]]),
  !anyDuplicated(annotation$BioReplicate),
  setequal(annotation$Group, c("Reference", "Treatment")),
  setequal(sort(unique(annotation$Time)), c(12, 24, 48, 72, 96, 120)),
  all(table(annotation$Time, annotation$Group) == 5L),
  all(contrasts$Condition %in% paste0(
    rep(sort(unique(annotation$Time)), each = 2L),
    "h_", rep(c("Reference", "Treatment"), times = 6L)
  ))
)

weight_sums <- aggregate(Weight ~ Label, contrasts, sum)
stopifnot(all(abs(weight_sums$Weight) < 1e-12))

public_text <- tolower(paste(
  readLines(psm_file, warn = FALSE),
  readLines(annotation_file, warn = FALSE),
  collapse = "\n"
))
forbidden <- c("ogolaeo", "langat", "lgtv", "CNI_", "PIA26", "A0A8C0")
stopifnot(!any(vapply(
  tolower(forbidden),
  grepl,
  logical(1),
  x = public_text,
  fixed = TRUE
)))

cat("De-identified example data: PASS\n")
