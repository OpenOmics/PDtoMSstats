#!/usr/bin/env Rscript

script_argument <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
script_file <- sub("^--file=", "", script_argument[[1]])
repo_root <- normalizePath(
  file.path(dirname(script_file), ".."), winslash = "/", mustWork = TRUE
)
source(file.path(repo_root, "R", "contrast-functions.R"))

test_table <- data.frame(
  ContrastType = c(
    "pairwise", "pairwise",
    rep("linear_trend_difference", 4)
  ),
  Label = c(
    "Treatment_vs_Control", "Treatment_vs_Control",
    rep("Treatment_vs_Control_linear_trend_per_24h", 4)
  ),
  Condition = c(
    "Treatment", "Control",
    "Early_Treatment", "Late_Treatment", "Early_Control", "Late_Control"
  ),
  Weight = c(1, -1, -0.5, 0.5, 0.5, -0.5),
  stringsAsFactors = FALSE
)

validated <- validate_contrast_table(test_table)
matrix <- contrast_table_to_matrix(validated)
guide <- describe_contrasts(validated)

stopifnot(
  identical(dim(matrix), c(2L, 6L)),
  nrow(guide) == 2L,
  grepl("Treatment - Control", guide$Formula[[1]], fixed = TRUE),
  grepl("per 24 hours", guide$WhatItMeasures[[2]], fixed = TRUE),
  grepl("Nonlinear or transient", guide$ImportantLimitation[[2]], fixed = TRUE)
)

bad_weights <- test_table[1:2, ]
bad_weights$Weight <- c(1, -0.5)
bad_result <- try(validate_contrast_table(bad_weights), silent = TRUE)
stopifnot(inherits(bad_result, "try-error"))

source(file.path(repo_root, "scripts", "export_msstats_workbook.R"))
workbook <- openxlsx::createWorkbook()
openxlsx::addWorksheet(workbook, "Proteins")
add_contrast_guide_worksheet(workbook, guide)
workbook_file <- tempfile(fileext = ".xlsx")
openxlsx::saveWorkbook(workbook, workbook_file, overwrite = TRUE)
saved_guide <- openxlsx::read.xlsx(workbook_file, sheet = "Contrast Guide")
stopifnot(
  "Contrast Guide" %in% openxlsx::getSheetNames(workbook_file),
  identical(names(saved_guide), names(guide)),
  nrow(saved_guide) == nrow(guide)
)

column_test_workbook <- openxlsx::createWorkbook()
openxlsx::addWorksheet(column_test_workbook, "Proteins")
openxlsx::writeData(
  column_test_workbook, "Proteins", "Top header",
  startRow = 1, startCol = 1, colNames = FALSE
)
openxlsx::writeData(
  column_test_workbook, "Proteins", "Trailing peptide field",
  startRow = 3, startCol = 5, colNames = FALSE
)
stopifnot(worksheet_last_used_column(column_test_workbook, "Proteins") == 5L)

cat("Contrast functions: PASS\n")
