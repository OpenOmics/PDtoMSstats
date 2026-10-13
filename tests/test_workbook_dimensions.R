#!/usr/bin/env Rscript

script_argument <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
script_file <- sub("^--file=", "", script_argument[[1]])
repo_root <- normalizePath(
  file.path(dirname(script_file), ".."), winslash = "/", mustWork = TRUE
)

source(file.path(repo_root, "scripts", "export_msstats_workbook.R"))

workbook <- openxlsx::createWorkbook()
openxlsx::addWorksheet(workbook, "DE test")
openxlsx::writeData(
  workbook,
  "DE test",
  data.frame(Protein = c("P1", "P2"), log2FC = c(1, -1))
)
workbook$worksheets[[1]]$dimension <- "<dimension ref=\"A1\"/>"

repair_worksheet_dimensions(workbook)
stopifnot(identical(
  workbook$worksheets[[1]]$dimension,
  "<dimension ref=\"A1:B3\"/>"
))

output_file <- tempfile(fileext = ".xlsx")
on.exit(unlink(output_file), add = TRUE)
openxlsx::saveWorkbook(workbook, output_file, overwrite = TRUE)
worksheet_xml <- paste(
  readLines(unz(output_file, "xl/worksheets/sheet1.xml"), warn = FALSE),
  collapse = ""
)
stopifnot(grepl('<dimension ref="A1:B3"', worksheet_xml, fixed = TRUE))

gsea_dir <- tempfile("gsea-workbook-table-")
dir.create(gsea_dir)
on.exit(unlink(gsea_dir, recursive = TRUE), add = TRUE)
data.table::fwrite(
  data.frame(
    ID = character(), Description = character(), pvalue = numeric(),
    p.adjust = numeric()
  ),
  file.path(gsea_dir, "gsea_go_bp_il10_vs_nc-il10.csv")
)
expected_status <- paste(
  "Skipped: only 83 unique Entrez IDs were mapped;",
  "at least 100 are required."
)
data.table::fwrite(
  data.frame(
    Comparison = "IL10 vs NC-IL10",
    status = expected_status
  ),
  file.path(gsea_dir, "gsea_go_bp_run_summary.csv")
)
gsea_table <- gsea_workbook_table(gsea_dir, "IL10_vs_NC-IL10")
stopifnot(
  identical(names(gsea_table), "Note"),
  identical(gsea_table$Note[[1L]], expected_status)
)

cat("Workbook worksheet dimensions and GSEA diagnostics: PASS\n")
