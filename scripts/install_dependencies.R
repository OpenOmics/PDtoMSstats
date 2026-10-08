#!/usr/bin/env Rscript

install_cores <- suppressWarnings(as.integer(Sys.getenv(
  "PDTOMSTATS_INSTALL_CORES", unset = "2"
)))
if (!is.finite(install_cores) || install_cores < 1L) install_cores <- 2L
options(
  repos = c(CRAN = "https://cloud.r-project.org"),
  Ncpus = min(install_cores, max(1L, parallel::detectCores(logical = FALSE)))
)

script_argument <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
script_file <- sub("^--file=", "", script_argument[[1]])
repo_root <- normalizePath(
  file.path(dirname(script_file), ".."), winslash = "/", mustWork = TRUE
)
source(file.path(repo_root, "R", "dependencies.R"))

args <- commandArgs(trailingOnly = TRUE)
allowed_modes <- c("--check-only", "--cran-only", "--bioc-only")
if (length(args) > 1L || (length(args) == 1L && !args %in% allowed_modes)) {
  stop(
    paste0(
      "Usage: install_dependencies.R ",
      "[--check-only|--cran-only|--bioc-only]"
    ),
    call. = FALSE
  )
}
mode <- if (!length(args)) "all" else sub("^--", "", args[[1]])
check_only <- identical(mode, "check-only")
install_cran <- mode %in% c("all", "cran-only")
install_bioconductor <- mode %in% c("all", "bioc-only")

cran_packages <- pdtomsstats_cran_packages()
bioconductor_packages <- pdtomsstats_bioconductor_packages()

missing_cran <- cran_packages[
  !vapply(cran_packages, requireNamespace, logical(1), quietly = TRUE)
]
if (length(missing_cran) && install_cran) {
  install.packages(missing_cran)
}

# MSstats 4.16.1 declares C++11, while newer RcppArmadillo headers require
# C++14. This archived release is from the final C++11-compatible line. Remove
# the pin after MSstats raises its declared C++ standard.
armadillo_version <- "14.6.3-1"
armadillo_ok <- requireNamespace("RcppArmadillo", quietly = TRUE) &&
  utils::packageVersion("RcppArmadillo") == armadillo_version
if (!armadillo_ok && install_cran) {
  install.packages(
    sprintf(
      paste0(
        "https://cran.r-project.org/src/contrib/Archive/RcppArmadillo/",
        "RcppArmadillo_%s.tar.gz"
      ),
      armadillo_version
    ),
    repos = NULL,
    type = "source"
  )
}

missing_bioconductor <- bioconductor_packages[
  !vapply(bioconductor_packages, requireNamespace, logical(1), quietly = TRUE)
]
if (length(missing_bioconductor) && install_bioconductor) {
  bioconductor_version <- Sys.getenv("BIOCONDUCTOR_VERSION", unset = "")
  if (nzchar(bioconductor_version)) {
    BiocManager::install(
      version = bioconductor_version, ask = FALSE, update = FALSE
    )
  }
  BiocManager::install(
    missing_bioconductor,
    ask = FALSE,
    update = FALSE,
    Ncpus = getOption("Ncpus")
  )
}

required_packages <- if (identical(mode, "cran-only")) {
  c(cran_packages, "RcppArmadillo")
} else {
  pdtomsstats_required_packages()
}
still_missing <- required_packages[
  !vapply(required_packages, requireNamespace, logical(1), quietly = TRUE)
]
if (length(still_missing)) {
  action <- if (check_only) "Missing required package(s): " else
    "The following package(s) could not be installed: "
  stop(action, paste(still_missing, collapse = ", "), call. = FALSE)
}

cat("All required R packages are installed.\n")
if (!nzchar(Sys.which("quarto"))) {
  stop("Quarto was not found on PATH. Install it from https://quarto.org/.", call. = FALSE)
}
cat("Quarto:", Sys.which("quarto"), "\n")
