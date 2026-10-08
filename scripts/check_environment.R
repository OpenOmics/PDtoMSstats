#!/usr/bin/env Rscript

script_argument <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
script_file <- sub("^--file=", "", script_argument[[1]])
repo_root <- normalizePath(
  file.path(dirname(script_file), ".."), winslash = "/", mustWork = TRUE
)
source(file.path(repo_root, "R", "dependencies.R"))

required_packages <- pdtomsstats_required_packages()
installed <- vapply(required_packages, requireNamespace, logical(1), quietly = TRUE)
if (any(!installed)) {
  stop(
    "Missing required package(s): ",
    paste(required_packages[!installed], collapse = ", "),
    call. = FALSE
  )
}

quarto <- Sys.which("quarto")
if (!nzchar(quarto)) {
  stop("Quarto was not found on PATH.", call. = FALSE)
}

versions <- vapply(
  required_packages,
  function(package) as.character(utils::packageVersion(package)),
  character(1)
)

cat("PDtoMSstats environment check: PASS\n")
cat(R.version.string, "\n")
cat("Quarto:", system2(quarto, "--version", stdout = TRUE)[[1]], "\n")
cat("Bioconductor:", as.character(BiocManager::version()), "\n")
cat("Package versions:\n")
writeLines(paste0("  ", names(versions), ": ", versions))
