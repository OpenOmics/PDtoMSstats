pdtomsstats_cran_packages <- function() {
  c(
    "BiocManager",
    "data.table",
    "dplyr",
    "DT",
    "ggbreak",
    "ggplot2",
    "ggrepel",
    "htmltools",
    "knitr",
    "openxlsx",
    "openxlsx2",
    "purrr",
    "readr",
    "readxl",
    "scales",
    "stringr",
    "tibble",
    "tidyr",
    "xfun",
    "yaml"
  )
}

pdtomsstats_bioconductor_packages <- function() {
  c(
    "AnnotationDbi",
    "Biobase",
    "clusterProfiler",
    "EnhancedVolcano",
    "enrichplot",
    "maSigPro",
    "Mfuzz",
    "MSstats",
    "org.Hs.eg.db"
  )
}

pdtomsstats_required_packages <- function() {
  c(pdtomsstats_cran_packages(), pdtomsstats_bioconductor_packages())
}
