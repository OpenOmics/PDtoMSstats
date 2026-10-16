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

limit <- log2(100)
stopifnot(isTRUE(all.equal(
  cap_workbook_fold_changes(c(-Inf, -8, -1, 0, 1, 8, Inf, NA_real_)),
  c(-limit, -limit, -1, 0, 1, limit, limit, NA_real_)
)))
stopifnot(isTRUE(all.equal(
  cap_workbook_fold_changes(c(-Inf, Inf), 1000),
  c(-log2(1000), log2(1000))
)))
for (invalid_limit in list(0, -1, Inf, NA_real_, numeric(), c(10, 100))) {
  stopifnot(inherits(tryCatch(
    cap_workbook_fold_changes(1, invalid_limit), error = identity
  ), "error"))
}

# Exercise complete exports so sorting must preserve metadata, statistics,
# text labels, and peptide hierarchy together, rather than just a sort key.
fixture_dir <- tempfile("protein-workbook-export-")
dir.create(fixture_dir)
on.exit(unlink(fixture_dir, recursive = TRUE), add = TRUE)
fixture_input <- file.path(fixture_dir, "input.xlsx")
fixture_objects <- file.path(fixture_dir, "objects.rds")
fixture <- openxlsx::createWorkbook()
openxlsx::addWorksheet(fixture, "Proteins")
peptide_tail_headers <- c(
  "Positions in Proteins", "Quan Usage", "Quan Ratio Usage"
)
source_headers <- c(
  "Role", "Confidence", "Accession", "Description", "# PSMs", "PD log2FC",
  rep(NA_character_, length(peptide_tail_headers))
)
source_rows <- list(source_headers)
for (index in seq_len(4L)) {
  source_rows <- c(source_rows, list(
    c("Master Protein", "High", paste0("P", index), paste("Protein", index),
      c("20", "30", "10", NA_character_)[index], "1", NA, NA, NA),
    c(NA, "Confidence", "Accession", "Sequence", NA, NA,
      peptide_tail_headers),
    c(NA, "High", NA, "PEPTIDE", NA, NA,
      "[1-7]", "Used (Top N)", "Used")
  ))
}
source_rows <- c(source_rows, list(
  c("Master Protein Candidate", "High", "C1", "Candidate", "100", "-1",
    NA, NA, NA)
))
openxlsx::writeData(fixture, "Proteins", do.call(rbind, source_rows), colNames = FALSE)
openxlsx::saveWorkbook(fixture, fixture_input)
protein_level <- data.frame(
  Protein = rep(paste0("P", 1:4), each = 2),
  Run = rep(c("R1", "R2"), 4),
  Condition = rep(c("Control", "Treatment"), 4),
  LogIntensities = seq_len(8) + 10
)
comparison <- data.frame(
  Protein = paste0("P", 1:4), Label = "Treatment_vs_Control",
  log2FC = c(Inf, -Inf, 8, NA_real_),
  SE = c(Inf, -Inf, 0.1, NA_real_),
  adj.pvalue = c(0.01, 0.02, 0.03, NA_real_)
)
objects <- list(
  msstats_input = data.frame(
    ProteinName = protein_level$Protein,
    PeptideModifiedSequence = "PEPTIDE", Run = protein_level$Run,
    Intensity = 2^protein_level$LogIntensities
  ),
  protein_level_data = protein_level,
  annotation = data.frame(
    Run = c("R1", "R2"), SampleName = c("R1", "R2"),
    Condition = c("Control", "Treatment")
  ),
  comparison_results = comparison,
  analysis_settings = list(normalization = FALSE)
)
saveRDS(protein_level, file.path(fixture_dir, "msstats_unnormalized_protein_level.rds"))
saveRDS(objects, fixture_objects)
single_output <- file.path(fixture_dir, "single.xlsx")
export_msstats_workbook(fixture_input, fixture_objects, fixture_dir, single_output)
single <- openxlsx::read.xlsx(single_output, sheet = "Proteins", check.names = FALSE, sep.names = " ")
stopifnot(
  identical(single$Accession, c("P1", "P3", "P2", "P4", "C1")),
  isTRUE(all.equal(as.numeric(single[["MSstats Treatment_vs_Control: log2FC"]][1:3]), c(limit, limit, -limit))),
  isTRUE(all.equal(as.numeric(single[["MSstats Treatment_vs_Control: Ratio"]][1:3]), c(100, 100, 0.01))),
  single[["MSstats Treatment_vs_Control: SE"]][1] == "Inf",
  single[["MSstats Treatment_vs_Control: SE"]][3] == "-Inf"
)
uncapped <- openxlsx::read.xlsx(single_output, sheet = "All MSstats Results", check.names = FALSE, sep.names = " ")
stopifnot(
  identical(as.character(uncapped$log2FC[1:3]), c("Inf", "-Inf", "8")),
  identical(objects$comparison_results$log2FC, comparison$log2FC)
)
peptide <- openxlsx::read.xlsx(single_output, sheet = "Peptide", check.names = FALSE, sep.names = " ")
stopifnot(identical(peptide$Accession[peptide$Role %in% "Master Protein"], paste0("P", 1:4)))
single_last_col <- ncol(peptide)
tail_columns <- seq.int(single_last_col - length(peptide_tail_headers) + 1L, single_last_col)
single_peptide_raw <- openxlsx::read.xlsx(
  single_output, sheet = "Peptide", rows = 1:4,
  cols = seq_len(single_last_col), colNames = FALSE,
  skipEmptyRows = FALSE, skipEmptyCols = FALSE
)
stopifnot(
  identical(ncol(single), single_last_col - length(peptide_tail_headers)),
  identical(grep("^MSstats ", names(single)), 7:22),
  identical(
    as.character(unlist(single_peptide_raw[3, tail_columns], use.names = FALSE)),
    peptide_tail_headers
  ),
  identical(
    as.character(unlist(single_peptide_raw[4, tail_columns], use.names = FALSE)),
    c("[1-7]", "Used (Top N)", "Used")
  )
)
single_wb <- openxlsx::loadWorkbook(single_output)
protein_sheet_index <- match("Proteins", names(single_wb))
protein_xml <- paste(
  single_wb$worksheets[[protein_sheet_index]]$conditionalFormatting,
  collapse = ""
)
stopifnot(
  grepl('type="colorScale"', protein_xml, fixed = TRUE),
  grepl('type="num" val="0"', protein_xml, fixed = TRUE),
  grepl("FF2166AC", protein_xml, fixed = TRUE),
  grepl("FFB2182B", protein_xml, fixed = TRUE)
)

# Re-exporting an already augmented workbook must replace the MSstats block
# without duplicating or displacing the peptide-only tail columns.
single_rerun_output <- file.path(fixture_dir, "single-rerun.xlsx")
export_msstats_workbook(
  single_output, fixture_objects, fixture_dir, single_rerun_output
)
single_rerun <- openxlsx::read.xlsx(
  single_rerun_output, sheet = "Proteins", check.names = FALSE, sep.names = " "
)
single_rerun_peptide <- openxlsx::read.xlsx(
  single_rerun_output, sheet = "Peptide", check.names = FALSE, sep.names = " "
)
single_rerun_last_col <- ncol(single_rerun_peptide)
single_rerun_peptide_raw <- openxlsx::read.xlsx(
  single_rerun_output, sheet = "Peptide", rows = 1:4,
  cols = seq_len(single_rerun_last_col), colNames = FALSE,
  skipEmptyRows = FALSE, skipEmptyCols = FALSE
)
rerun_tail_columns <- seq.int(
  single_rerun_last_col - length(peptide_tail_headers) + 1L,
  single_rerun_last_col
)
stopifnot(
  identical(single_rerun_last_col, single_last_col),
  identical(grep("^MSstats ", names(single_rerun)), 7:22),
  identical(
    as.character(unlist(
      single_rerun_peptide_raw[3, rerun_tail_columns], use.names = FALSE
    )),
    peptide_tail_headers
  )
)

# Multiple comparisons use PSM counts, including master-protein candidates.
objects$comparison_results <- rbind(comparison, transform(comparison, Label = "Other_vs_Control"))
saveRDS(objects, fixture_objects)
multi_output <- file.path(fixture_dir, "multi.xlsx")
export_msstats_workbook(
  fixture_input, fixture_objects, fixture_dir, multi_output,
  maximum_allowed_fold_change = 1000
)
multi <- openxlsx::read.xlsx(multi_output, sheet = "Proteins", check.names = FALSE, sep.names = " ")
stopifnot(
  identical(multi$Accession, c("C1", "P2", "P1", "P3", "P4")),
  isTRUE(all.equal(as.numeric(multi[["MSstats Treatment_vs_Control: log2FC"]][2:3]), c(-log2(1000), log2(1000)))),
  isTRUE(all.equal(as.numeric(multi[["MSstats Other_vs_Control: Ratio"]][2:3]), c(0.001, 1000)))
)

cat("Workbook dimensions, peptide-tail layout, GSEA diagnostics, fold-change cap, sorting, and gradients: PASS\n")
