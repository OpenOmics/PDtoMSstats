#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(data.table)
  library(openxlsx)
})

preferred_protein_sheet <- function(workbook) {
  sheet_names <- names(workbook)
  if (!length(sheet_names)) return(NULL)
  if ("Peptide" %in% sheet_names) return("Peptide")
  if ("Peptides" %in% sheet_names) return("Peptides")
  if ("All_conditions Filtered" %in% sheet_names) return("All_conditions Filtered")
  if ("Proteins" %in% sheet_names) return("Proteins")
  sheet_names[[1]]
}

excel_nonfinite_label <- function(value) {
  if (is.infinite(value)) {
    if (value > 0) "Inf" else "-Inf"
  } else {
    "NA"
  }
}

prepare_excel_data <- function(data) {
  original <- as.data.frame(data, stringsAsFactors = FALSE, check.names = FALSE)
  safe <- original
  labels <- list()

  for (column_index in seq_along(original)) {
    values <- original[[column_index]]
    if (!is.numeric(values)) next
    invalid_rows <- which(!is.finite(values))
    if (!length(invalid_rows)) next

    labels[[length(labels) + 1L]] <- data.frame(
      row = invalid_rows,
      col = column_index,
      value = vapply(values[invalid_rows], excel_nonfinite_label, character(1)),
      stringsAsFactors = FALSE
    )
    safe[[column_index]][invalid_rows] <- NA_real_
  }

  list(
    data = safe,
    labels = if (length(labels)) do.call(rbind, labels) else data.frame(
      row = integer(), col = integer(), value = character()
    )
  )
}

write_excel_labels <- function(
  workbook, sheet, labels, start_row = 1L, start_col = 1L
) {
  if (!nrow(labels)) return(invisible(workbook))
  for (label_index in seq_len(nrow(labels))) {
    writeData(
      workbook, sheet, labels$value[[label_index]],
      startRow = start_row + labels$row[[label_index]] - 1L,
      startCol = start_col + labels$col[[label_index]] - 1L,
      colNames = FALSE, rowNames = FALSE
    )
  }
  invisible(workbook)
}

worksheet_last_used_column <- function(workbook, sheet) {
  sheet_index <- match(sheet, names(workbook))
  if (is.na(sheet_index)) {
    stop("Worksheet was not found: ", sheet, call. = FALSE)
  }

  used_columns <- suppressWarnings(as.integer(
    workbook$worksheets[[sheet_index]]$sheet_data$cols
  ))
  used_columns <- used_columns[is.finite(used_columns) & used_columns > 0L]
  if (!length(used_columns)) {
    stop("The worksheet contains no readable columns: ", sheet, call. = FALSE)
  }
  max(used_columns)
}

try_openxlsx_workbook <- function(file) {
  tryCatch({
    workbook <- openxlsx::loadWorkbook(file)
    sheet <- preferred_protein_sheet(workbook)
    if (is.null(sheet)) stop("the workbook contains no readable worksheets")

    preview <- suppressWarnings(openxlsx::readWorkbook(
      workbook, sheet,
      rows = 1:1000, cols = 1:4,
      colNames = FALSE,
      skipEmptyRows = FALSE,
      skipEmptyCols = FALSE
    ))
    has_values <- is.data.frame(preview) && nrow(preview) > 0L &&
      any(vapply(preview, function(column) {
        values <- as.character(column)
        any(!is.na(values) & nzchar(values))
      }, logical(1)))
    if (!has_values) {
      stop("the main worksheet contains no cells readable by openxlsx")
    }

    list(workbook = workbook, error = NULL)
  }, error = function(error) {
    list(workbook = NULL, error = conditionMessage(error))
  })
}

load_protein_workbook <- function(file) {
  first_attempt <- try_openxlsx_workbook(file)
  if (!is.null(first_attempt$workbook)) {
    message("Workbook compatibility check: PASS")
    return(first_attempt$workbook)
  }

  if (!requireNamespace("openxlsx2", quietly = TRUE)) {
    stop(
      "The workbook is not directly readable by openxlsx. Install the R package ",
      "openxlsx2 with install.packages(\"openxlsx2\"), or open the workbook in ",
      "Excel/LibreOffice and save it as a new .xlsx file. ",
      "The original workbook was not changed. Initial openxlsx error: ",
      first_attempt$error,
      call. = FALSE
    )
  }

  converted_file <- tempfile(pattern = "msstats-compatible-", fileext = ".xlsx")
  on.exit(unlink(converted_file), add = TRUE)
  conversion_error <- tryCatch({
    compatibility_workbook <- suppressWarnings(openxlsx2::wb_load(file))
    suppressWarnings(openxlsx2::wb_save(
      compatibility_workbook,
      converted_file,
      overwrite = TRUE
    ))
    NULL
  }, error = function(error) conditionMessage(error))
  if (!is.null(conversion_error) || !file.exists(converted_file)) {
    stop(
      "The workbook needs compatibility conversion, but automatic R conversion failed. ",
      if (!is.null(conversion_error)) conversion_error else "No converted file was created.",
      " Re-save the workbook in Excel/LibreOffice and try again. The original ",
      "workbook was not changed.",
      call. = FALSE
    )
  }

  second_attempt <- try_openxlsx_workbook(converted_file)
  if (is.null(second_attempt$workbook)) {
    stop(
      "The workbook remained unreadable after automatic compatibility conversion: ",
      second_attempt$error,
      call. = FALSE
    )
  }

  message(
    "Workbook compatibility check: converted a temporary copy with R openxlsx2; ",
    "the original file was not changed."
  )
  second_attempt$workbook
}

add_contrast_guide_worksheet <- function(wb, contrast_guide) {
  contrast_guide <- as.data.frame(contrast_guide, stringsAsFactors = FALSE)
  if ("Contrast Guide" %in% names(wb)) removeWorksheet(wb, "Contrast Guide")
  addWorksheet(wb, "Contrast Guide")

  guide_header_style <- createStyle(
    fontColour = "#FFFFFF", fgFill = "#27445C", textDecoration = "bold",
    halign = "center", valign = "center", wrapText = TRUE
  )
  writeData(
    wb, "Contrast Guide", contrast_guide,
    withFilter = nrow(contrast_guide) > 0L,
    headerStyle = guide_header_style
  )
  freezePane(wb, "Contrast Guide", firstRow = TRUE)

  guide_widths <- c(24, 38, 70, 70, 70, 70, 70, 70)
  setColWidths(
    wb, "Contrast Guide", cols = seq_len(ncol(contrast_guide)),
    widths = rep(guide_widths, length.out = ncol(contrast_guide))
  )
  if (nrow(contrast_guide) > 0L) {
    guide_rows <- 2:(nrow(contrast_guide) + 1L)
    setRowHeights(wb, "Contrast Guide", rows = guide_rows, heights = 72)
    addStyle(
      wb, "Contrast Guide",
      createStyle(fgFill = "#E2F0D9", wrapText = TRUE, valign = "top"),
      rows = guide_rows, cols = seq_len(ncol(contrast_guide)),
      gridExpand = TRUE, stack = TRUE
    )
  }
  invisible(wb)
}

export_msstats_workbook <- function(
  input_file, objects_file, results_dir, output_file = NULL
) {
input_file <- normalizePath(input_file, winslash = "/", mustWork = TRUE)
objects_file <- normalizePath(objects_file, winslash = "/", mustWork = TRUE)
results_dir <- normalizePath(results_dir, winslash = "/", mustWork = TRUE)
default_output_file <- file.path(
  dirname(input_file),
  paste0(tools::file_path_sans_ext(basename(input_file)), "_MSstats.xlsx")
)
output_file <- if (is.null(output_file)) default_output_file else output_file
unnormalized_file <- file.path(results_dir, "msstats_unnormalized_protein_level.rds")

objects <- readRDS(objects_file)
required_objects <- c("msstats_input", "protein_level_data", "annotation", "comparison_results")
missing_objects <- setdiff(required_objects, names(objects))
if (length(missing_objects)) {
  stop("Missing exported object(s): ", paste(missing_objects, collapse = ", "), call. = FALSE)
}
if (!file.exists(unnormalized_file)) {
  stop(
    "Missing unnormalized protein results: ", unnormalized_file,
    ". Run calculate_unnormalized_msstats_protein_abundance.R first.",
    call. = FALSE
  )
}

clean_peptide <- function(x) {
  x <- sub("NA$", "", as.character(x))
  flanked <- grepl("^\\[[^]]+\\]\\..*\\.\\[[^]]+\\]$", x)
  x[flanked] <- sub("^\\[[^]]+\\]\\.(.*)\\.\\[[^]]+\\]$", "\\1", x[flanked])
  toupper(gsub("[^A-Za-z]", "", x))
}

required_column <- function(data, candidates, description) {
  found <- intersect(candidates, names(data))
  if (!length(found)) {
    stop(
      "Could not find ", description, ". Tried: ",
      paste(candidates, collapse = ", "),
      call. = FALSE
    )
  }
  found[[1]]
}

comparison_file_key <- function(label) {
  key <- gsub("[^A-Za-z0-9_-]+", "_", label)
  tolower(key)
}

annotation <- as.data.table(objects$annotation)
annotation[, Run := as.character(Run)]
if (!"SampleName" %in% names(annotation)) {
  sample_column <- required_column(
    annotation, c("File Name", "File", "Run"), "an annotation sample-name column"
  )
  annotation[, SampleName := tools::file_path_sans_ext(basename(as.character(get(sample_column))))]
}
annotation[, SampleName := as.character(SampleName)]
run_order <- annotation$Run
sample_names <- make.unique(annotation$SampleName)
names(sample_names) <- run_order
condition_order <- unique(as.character(annotation$Condition))
source_analysis_description <- paste0(
  nrow(annotation), "-run MSstats analysis from ", basename(objects_file),
  "; conditions: ", paste(condition_order, collapse = ", "), "."
)

settings <- objects$analysis_settings
normalization_method <- if (!is.null(settings$normalization)) {
  settings$normalization
} else {
  "equalizeMedians"
}
summary_method <- if (!is.null(settings$summary_method)) {
  as.character(settings$summary_method)
} else {
  "TMP"
}
fdr_cutoff <- if (!is.null(settings$differential_fdr_cutoff)) {
  as.numeric(settings$differential_fdr_cutoff)
} else {
  0.05
}
log2fc_cutoff <- if (!is.null(settings$differential_log2fc_cutoff)) {
  as.numeric(settings$differential_log2fc_cutoff)
} else {
  1
}

# PDtoMSstatsFormat has already resolved duplicate feature/run rows according to
# the report settings. Equalize-medians is an additive run shift on log2 values.
peptides <- as.data.table(objects$msstats_input)
peptides <- peptides[is.finite(Intensity) & Intensity > 0]
peptides[, `:=`(
  Protein = as.character(ProteinName),
  Peptide = clean_peptide(PeptideModifiedSequence),
  Run = as.character(Run),
  Log2Intensity = log2(Intensity)
)]
if (identical(normalization_method, "equalizeMedians")) {
  run_medians <- peptides[, .(RunMedian = median(Log2Intensity, na.rm = TRUE)), by = Run]
  global_median <- median(run_medians$RunMedian, na.rm = TRUE)
  peptides[run_medians, on = "Run", RunMedian := i.RunMedian]
  peptides[, NormalizedIntensity := Intensity * 2^(global_median - RunMedian)]
} else if (identical(normalization_method, FALSE) ||
           tolower(as.character(normalization_method)) %in% c("false", "none")) {
  peptides[, NormalizedIntensity := Intensity]
} else {
  stop(
    "Peptide export currently supports equalizeMedians or no normalization; found: ",
    normalization_method,
    call. = FALSE
  )
}

peptide_summary <- peptides[, .(
  CalculatedAbundance = sum(Intensity, na.rm = TRUE),
  NormalizedAbundance = sum(NormalizedIntensity, na.rm = TRUE)
), by = .(Protein, Peptide, Run)]
peptide_summary[, Key := paste(Protein, Peptide, sep = "\r")]

make_wide_matrix <- function(dt, value_col, keys, runs) {
  wide <- dcast(dt, Key ~ Run, value.var = value_col)
  missing_runs <- setdiff(runs, names(wide))
  for (run in missing_runs) wide[, (run) := NA_real_]
  wide <- wide[, c("Key", runs), with = FALSE]
  idx <- match(keys, wide$Key)
  as.matrix(wide[idx, ..runs])
}

wb <- load_protein_workbook(input_file)
template_sheet_order <- names(wb)
main_sheet <- preferred_protein_sheet(wb)
meta <- readWorkbook(
  wb, main_sheet, cols = 1:4, colNames = FALSE,
  skipEmptyRows = FALSE, skipEmptyCols = FALSE
)
n_rows <- nrow(meta)

protein_rows <- which(meta[[1]] == "Master Protein")
protein_candidate_rows <- which(meta[[1]] == "Master Protein Candidate")
protein_display_rows <- sort(c(protein_rows, protein_candidate_rows))
peptide_header_rows <- which(
  is.na(meta[[1]]) & !is.na(meta[[2]]) & meta[[2]] == "Confidence"
)
peptide_rows <- which(
  is.na(meta[[1]]) & !is.na(meta[[2]]) & meta[[2]] != "Confidence" &
    !is.na(meta[[4]]) & nzchar(as.character(meta[[4]]))
)
if (!length(protein_rows) || !length(peptide_header_rows) || !length(peptide_rows)) {
  stop(
    "The main worksheet must contain hierarchical protein, peptide-header, and peptide rows.",
    call. = FALSE
  )
}
parent_index <- findInterval(peptide_rows, protein_rows)
if (any(parent_index == 0L)) {
  stop("Found a peptide row before its parent protein row.", call. = FALSE)
}
parent_accession <- as.character(meta[[3]][protein_rows[parent_index]])
peptide_keys <- paste(parent_accession, clean_peptide(meta[[4]][peptide_rows]), sep = "\r")
protein_accessions <- as.character(meta[[3]][protein_rows])

calculated_matrix <- make_wide_matrix(
  peptide_summary, "CalculatedAbundance", peptide_keys, run_order
)
normalized_peptide_matrix <- make_wide_matrix(
  peptide_summary, "NormalizedAbundance", peptide_keys, run_order
)

protein_level <- as.data.table(objects$protein_level_data)
protein_column <- required_column(
  protein_level, c("Protein", "PROTEIN", "ProteinName"), "a protein identifier column"
)
run_column <- required_column(
  protein_level, c("originalRUN", "RUN", "Run"), "a protein-level run column"
)
group_column <- required_column(
  protein_level, c("GROUP", "GROUP_ORIGINAL", "Condition"), "a protein-level condition column"
)
value_column <- required_column(
  protein_level, c("LogIntensities", "log2Intensity", "ABUNDANCE"),
  "a protein-level abundance column"
)
protein_level[, `:=`(
  Protein = as.character(get(protein_column)),
  ExportRun = as.character(get(run_column)),
  ExportGroup = as.character(get(group_column)),
  ExportLog2Abundance = as.numeric(get(value_column))
)]
protein_wide <- dcast(
  protein_level, Protein ~ ExportRun, value.var = "ExportLog2Abundance",
  fun.aggregate = function(x) if (length(x)) mean(x, na.rm = TRUE) else NA_real_
)
for (run in setdiff(run_order, names(protein_wide))) protein_wide[, (run) := NA_real_]
protein_idx <- match(protein_accessions, protein_wide$Protein)
protein_sample_matrix <- as.matrix(protein_wide[protein_idx, ..run_order])

unnormalized_protein_level <- as.data.table(readRDS(unnormalized_file))
unnormalized_protein_column <- required_column(
  unnormalized_protein_level, c("Protein", "PROTEIN", "ProteinName"),
  "an unnormalized protein identifier column"
)
unnormalized_run_column <- required_column(
  unnormalized_protein_level, c("originalRUN", "RUN", "Run"),
  "an unnormalized run column"
)
unnormalized_value_column <- required_column(
  unnormalized_protein_level, c("LogIntensities", "log2Intensity", "ABUNDANCE"),
  "an unnormalized abundance column"
)
unnormalized_protein_level[, `:=`(
  Protein = as.character(get(unnormalized_protein_column)),
  ExportRun = as.character(get(unnormalized_run_column)),
  ExportLog2Abundance = as.numeric(get(unnormalized_value_column))
)]
unnormalized_wide <- dcast(
  unnormalized_protein_level, Protein ~ ExportRun,
  value.var = "ExportLog2Abundance",
  fun.aggregate = function(x) if (length(x)) mean(x, na.rm = TRUE) else NA_real_
)
for (run in setdiff(run_order, names(unnormalized_wide))) {
  unnormalized_wide[, (run) := NA_real_]
}
unnormalized_idx <- match(protein_accessions, unnormalized_wide$Protein)
unnormalized_protein_matrix <- as.matrix(
  unnormalized_wide[unnormalized_idx, ..run_order]
)

group_summary <- protein_level[, .(
  GroupAbundanceLog2 = mean(ExportLog2Abundance, na.rm = TRUE)
), by = .(Protein, ExportGroup)]
group_order <- condition_order[condition_order %in% unique(group_summary$ExportGroup)]
group_wide <- dcast(group_summary, Protein ~ ExportGroup, value.var = "GroupAbundanceLog2")
for (group in setdiff(group_order, names(group_wide))) group_wide[, (group) := NA_real_]
group_idx <- match(protein_accessions, group_wide$Protein)
group_matrix <- as.matrix(group_wide[group_idx, ..group_order])

comparisons <- as.data.table(objects$comparison_results)
comparison_order <- unique(as.character(comparisons$Label))
if (!length(comparison_order)) {
  stop("No comparison labels were found in comparison_results.", call. = FALSE)
}
stat_fields <- c(
  "Ratio", "log2FC", "SE", "Tvalue", "DF", "pvalue", "adj.pvalue",
  "MissingPercentage", "ImputationPercentage", "issue"
)

protein_headers <- c(
  paste0(
    "MSstats Protein Unnormalized ", summary_method,
    " Abundance (log2; no imputation): ", sample_names
  ),
  paste0("MSstats Protein Normalized Abundance (log2): ", sample_names),
  paste0("MSstats Group Abundance (mean log2): ", group_order),
  unlist(lapply(comparison_order, function(label) {
    paste0("MSstats ", label, ": ", stat_fields)
  }), use.names = FALSE)
)
peptide_headers <- c(
  paste0("MSstats Peptide Calculated Abundance (linear): ", sample_names),
  paste0("MSstats Peptide Normalized Abundance (linear): ", sample_names),
  rep(NA_character_, length(group_order) + length(comparison_order) * length(stat_fields))
)

n_new_cols <- length(protein_headers)
new_data <- setNames(
  lapply(seq_len(n_new_cols), function(i) rep(NA_real_, n_rows)),
  protein_headers
)
issue_columns <- grep(": issue$", protein_headers)
for (i in issue_columns) new_data[[i]] <- rep(NA_character_, n_rows)

calc_cols <- seq_along(run_order)
norm_cols <- max(calc_cols) + seq_along(run_order)
group_cols <- max(norm_cols) + seq_along(group_order)
new_data[calc_cols] <- lapply(seq_along(calc_cols), function(j) {
  x <- rep(NA_real_, n_rows)
  x[peptide_rows] <- calculated_matrix[, j]
  x[protein_rows] <- unnormalized_protein_matrix[, j]
  x
})
new_data[norm_cols] <- lapply(seq_along(norm_cols), function(j) {
  x <- rep(NA_real_, n_rows)
  x[peptide_rows] <- normalized_peptide_matrix[, j]
  x[protein_rows] <- protein_sample_matrix[, j]
  x
})
new_data[group_cols] <- lapply(seq_along(group_cols), function(j) {
  x <- rep(NA_real_, n_rows); x[protein_rows] <- group_matrix[, j]; x
})

comparisons[, Ratio := 2^log2FC]
stats_start <- max(group_cols) + 1L
main_nonfinite_labels <- list()
for (comparison_i in seq_along(comparison_order)) {
  label <- comparison_order[[comparison_i]]
  result <- comparisons[Label == label]
  result_idx <- match(protein_accessions, result$Protein)
  col_start <- stats_start + (comparison_i - 1L) * length(stat_fields)
  for (field_i in seq_along(stat_fields)) {
    field <- stat_fields[[field_i]]
    out_col <- col_start + field_i - 1L
    if (!field %in% names(result)) {
      if (field == "issue") {
        x <- rep(NA_character_, n_rows)
      } else {
        x <- rep(NA_real_, n_rows)
      }
    } else if (field == "issue") {
      x <- rep(NA_character_, n_rows)
      x[protein_rows] <- as.character(result[[field]][result_idx])
    } else {
      x <- rep(NA_real_, n_rows)
      values <- as.numeric(result[[field]][result_idx])
      matched <- !is.na(result_idx)
      invalid <- matched & !is.finite(values)
      x[protein_rows] <- values
      x[protein_rows[invalid]] <- NA_real_
      if (any(invalid)) {
        main_nonfinite_labels[[length(main_nonfinite_labels) + 1L]] <- data.frame(
          row = protein_rows[invalid],
          col = out_col,
          value = vapply(values[invalid], excel_nonfinite_label, character(1)),
          stringsAsFactors = FALSE
        )
      }
    }
    new_data[[out_col]] <- x
  }
}
main_nonfinite_labels <- if (length(main_nonfinite_labels)) {
  do.call(rbind, main_nonfinite_labels)
} else {
  data.frame(row = integer(), col = integer(), value = character())
}

# Values that are absent from abundance matrices remain blank. NaN or infinite
# values are also made blank so openxlsx cannot turn them into Excel errors.
for (column_index in seq_along(new_data)) {
  if (!is.numeric(new_data[[column_index]])) next
  invalid <- is.nan(new_data[[column_index]]) |
    is.infinite(new_data[[column_index]])
  new_data[[column_index]][invalid] <- NA_real_
}
new_data <- as.data.frame(new_data, check.names = FALSE)

main_sheet_index <- match(main_sheet, names(wb))
source_last_col <- worksheet_last_used_column(wb, main_sheet)

original_header <- readWorkbook(
  wb, main_sheet, rows = 1, cols = seq_len(source_last_col), colNames = FALSE,
  skipEmptyRows = FALSE, skipEmptyCols = FALSE
)
original_header_values <- as.character(unlist(original_header[1, ], use.names = FALSE))
existing_msstats_cols <- grep("^MSstats($|[[:space:]])", original_header_values)
start_col <- if (length(existing_msstats_cols)) {
  min(existing_msstats_cols)
} else {
  source_last_col + 1L
}
original_last_col <- start_col - 1L
original_table <- readWorkbook(
  wb, main_sheet, rows = seq_len(n_rows), cols = seq_len(original_last_col),
  colNames = FALSE, skipEmptyRows = FALSE, skipEmptyCols = FALSE
)
if (length(existing_msstats_cols)) {
  # Clear the complete earlier MSstats block so removed runs or comparisons
  # cannot leave stale columns at the right edge of the worksheet.
  deleteData(
    wb, main_sheet,
    cols = seq.int(min(existing_msstats_cols), max(existing_msstats_cols)),
    rows = seq_len(n_rows + 1L),
    gridExpand = TRUE
  )
}
writeData(
  wb, main_sheet, new_data[-1, , drop = FALSE], startCol = start_col,
  startRow = 2, colNames = FALSE, rowNames = FALSE, keepNA = FALSE
)
writeData(wb, main_sheet, t(protein_headers), startCol = start_col, startRow = 1, colNames = FALSE)
writeData(wb, main_sheet, t(peptide_headers), startCol = start_col, startRow = 3, colNames = FALSE)
if (nrow(main_nonfinite_labels)) {
  main_excel_labels <- main_nonfinite_labels
  main_excel_labels$col <- start_col + main_excel_labels$col - 1L
  write_excel_labels(wb, main_sheet, main_excel_labels)
}

# Match the hierarchical Proteome Discoverer layout used by the reference
# workbook. The rules are based on row roles and dynamic output blocks, rather
# than experiment-specific row or column numbers.
grid_borders <- c("top", "bottom", "left", "right")
grid_colour <- "#B3B3B3"
base_font <- list(fontName = "Calibri", fontSize = 11, fontColour = "#000000")

column_header_style <- do.call(createStyle, c(base_font, list(
  fgFill = "#A7CDF0", border = grid_borders,
  borderColour = grid_colour, borderStyle = "thin", wrapText = TRUE
)))
protein_row_style <- do.call(createStyle, c(base_font, list(
  fgFill = "#DDEBF7", border = grid_borders,
  borderColour = grid_colour, borderStyle = "thin", wrapText = TRUE
)))
protein_number_style <- do.call(createStyle, c(base_font, list(
  numFmt = "0.00", fgFill = "#DDEBF7", border = grid_borders,
  borderColour = grid_colour, borderStyle = "thin", wrapText = TRUE
)))
protein_scientific_style <- do.call(createStyle, c(base_font, list(
  numFmt = "0.00E+00", fgFill = "#DDEBF7", border = grid_borders,
  borderColour = grid_colour, borderStyle = "thin", wrapText = TRUE
)))
peptide_header_style <- do.call(createStyle, c(base_font, list(
  fgFill = "#F0CBA8", border = grid_borders,
  borderColour = grid_colour, borderStyle = "thin", wrapText = TRUE
)))
peptide_row_style <- do.call(createStyle, c(base_font, list(
  fgFill = "#FCE4D6", border = grid_borders,
  borderColour = grid_colour, borderStyle = "thin", wrapText = TRUE
)))
peptide_number_style <- do.call(createStyle, c(base_font, list(
  numFmt = "0.00E+00", fgFill = "#FCE4D6", border = grid_borders,
  borderColour = grid_colour, borderStyle = "thin", wrapText = TRUE
)))

last_output_col <- start_col + n_new_cols - 1L
peptide_abundance_cols <- start_col + seq_len(2L * length(run_order)) - 1L

# The reference workbook uses scientific notation for the peptide-level
# probability/score block and for abundance values. Text cells in this range
# are unaffected by the number format.
base_peptide_header <- readWorkbook(
  wb, main_sheet,
  rows = peptide_header_rows[[1]], cols = seq_len(original_last_col),
  colNames = FALSE, skipEmptyRows = FALSE, skipEmptyCols = FALSE
)
base_header_values <- as.character(unlist(base_peptide_header[1, ], use.names = FALSE))
first_probability_col <- which(
  grepl("^(q-?value|pep|svmscore)$", base_header_values, ignore.case = TRUE)
)[1]
scientific_original_cols <- if (!is.na(first_probability_col)) {
  seq.int(first_probability_col, original_last_col)
} else {
  integer()
}
scientific_peptide_cols <- sort(unique(c(
  scientific_original_cols,
  peptide_abundance_cols
)))

# Comparison p-values need scientific notation on protein rows even though
# the other MSstats summary fields are easier to read with two decimals.
probability_field_positions <- match(c("pvalue", "adj.pvalue"), stat_fields)
comparison_first_col <- start_col + stats_start - 1L
scientific_protein_cols <- unlist(lapply(
  seq_along(comparison_order),
  function(comparison_index) {
    comparison_first_col +
      (comparison_index - 1L) * length(stat_fields) +
      probability_field_positions - 1L
  }
), use.names = FALSE)

# Fixed column widths from the reference workbook. The frozen view is written
# below after all worksheets have been created because openxlsx does not retain
# freezePane() on some imported Proteome Discoverer worksheets.
setColWidths(wb, main_sheet, cols = 1:original_last_col, widths = 12)
wide_original_cols <- which(
  grepl(
    "Description|Biological Process|Cellular Component|Molecular Function|Positions in Proteins",
    original_header_values,
    ignore.case = TRUE
  ) & seq_along(original_header_values) <= original_last_col
)
if (length(wide_original_cols)) {
  setColWidths(wb, main_sheet, cols = wide_original_cols, widths = 40)
}
setColWidths(wb, main_sheet, cols = start_col:last_output_col, widths = 13)

# Header and hierarchy row heights mirror the reference layout.
setRowHeights(wb, main_sheet, rows = 1, heights = 135)
setRowHeights(wb, main_sheet, rows = peptide_header_rows, heights = 105)
setRowHeights(wb, main_sheet, rows = protein_display_rows, heights = 30)
long_description_rows <- protein_display_rows[
  nchar(as.character(meta[[4]][protein_display_rows])) > 100L
]
if (length(long_description_rows)) {
  setRowHeights(wb, main_sheet, rows = long_description_rows, heights = 45)
}

# Apply the reference hierarchy palette continuously across the worksheet.
# This includes collapsed peptide rows, so expanding a protein group does not
# reveal a differently coloured section at the MSstats join.
addStyle(wb, main_sheet, column_header_style, rows = 1, cols = 1:last_output_col, gridExpand = TRUE, stack = FALSE)
addStyle(wb, main_sheet, protein_row_style, rows = protein_display_rows, cols = 1:last_output_col, gridExpand = TRUE, stack = FALSE)
addStyle(wb, main_sheet, protein_number_style, rows = protein_display_rows, cols = start_col:last_output_col, gridExpand = TRUE, stack = FALSE)
addStyle(wb, main_sheet, protein_scientific_style, rows = protein_display_rows, cols = scientific_protein_cols, gridExpand = TRUE, stack = FALSE)
# Keep each collapsed peptide section visually continuous through the final
# column, including protein-only fields where peptide rows contain no value.
addStyle(wb, main_sheet, peptide_header_style, rows = peptide_header_rows, cols = 1:last_output_col, gridExpand = TRUE, stack = FALSE)
addStyle(wb, main_sheet, peptide_row_style, rows = peptide_rows, cols = 1:last_output_col, gridExpand = TRUE, stack = FALSE)
addStyle(wb, main_sheet, peptide_number_style, rows = peptide_rows, cols = scientific_peptide_cols, gridExpand = TRUE, stack = FALSE)

description <- as.character(meta[[4]][protein_rows])
gene_symbol <- sub(".* GN=([^ ]+).*", "\\1", description)
gene_symbol[gene_symbol == description] <- NA_character_
protein_annotation <- data.table(
  Protein = protein_accessions,
  GeneSymbol = gene_symbol,
  Description = description
)

header_style <- createStyle(
  fontColour = "#FFFFFF", fgFill = "#27445C", textDecoration = "bold",
  halign = "center", valign = "center", wrapText = TRUE
)
significant_fill <- createStyle(fgFill = "#E2F0D9")
scientific_result_style <- createStyle(numFmt = "0.00E+00")

replace_sheet <- function(sheet_name, data) {
  if (sheet_name %in% names(wb)) removeWorksheet(wb, sheet_name)
  addWorksheet(wb, sheet_name)
  prepared_data <- prepare_excel_data(data)
  writeData(
    wb, sheet_name, prepared_data$data,
    withFilter = nrow(data) > 0, headerStyle = header_style
  )
  write_excel_labels(
    wb, sheet_name, prepared_data$labels,
    start_row = 2L
  )
  freezePane(wb, sheet_name, firstRow = TRUE)
  setColWidths(wb, sheet_name, cols = seq_len(ncol(data)), widths = "auto")
  if (nrow(data) > 0) {
    addStyle(wb, sheet_name, significant_fill, rows = 2:(nrow(data) + 1), cols = 1:ncol(data), gridExpand = TRUE, stack = TRUE)
    normalized_names <- tolower(gsub("[^a-z0-9]", "", names(data)))
    scientific_columns <- which(normalized_names %in% c(
      "pvalue", "adjpvalue", "pval", "padjust", "qvalue", "fdr"
    ))
    if (length(scientific_columns)) {
      addStyle(
        wb, sheet_name, scientific_result_style,
        rows = 2:(nrow(data) + 1), cols = scientific_columns,
        gridExpand = TRUE, stack = TRUE
      )
    }
  }
}

contrast_guide <- objects$contrast_guide
contrast_guide_path <- file.path(results_dir, "msstats_contrast_guide.csv")
if (is.null(contrast_guide) && file.exists(contrast_guide_path)) {
  contrast_guide <- data.table::fread(contrast_guide_path, data.table = FALSE)
}
if (!is.null(contrast_guide)) {
  add_contrast_guide_worksheet(wb, contrast_guide)
}

all_results_sheet <- "All MSstats Results"
if (all_results_sheet %in% names(wb)) removeWorksheet(wb, all_results_sheet)
addWorksheet(wb, all_results_sheet)
all_results <- copy(comparisons)
setcolorder(
  all_results,
  c("Label", "Protein", setdiff(names(all_results), c("Label", "Protein")))
)
all_results_export <- prepare_excel_data(as.data.frame(all_results))
writeData(
  wb, all_results_sheet, all_results_export$data,
  withFilter = nrow(all_results) > 0L,
  headerStyle = header_style
)
write_excel_labels(
  wb, all_results_sheet, all_results_export$labels,
  start_row = 2L
)
freezePane(wb, all_results_sheet, firstRow = TRUE, firstActiveCol = 3L)
all_result_widths <- rep(14, ncol(all_results))
all_result_widths[names(all_results) == "Label"] <- 42
all_result_widths[names(all_results) == "Protein"] <- 28
all_result_widths[names(all_results) == "issue"] <- 30
setColWidths(
  wb, all_results_sheet,
  cols = seq_len(ncol(all_results)), widths = all_result_widths
)
all_result_names <- tolower(gsub("[^a-z0-9]", "", names(all_results)))
all_result_scientific_columns <- which(all_result_names %in% c(
  "pvalue", "adjpvalue", "pval", "padjust", "qvalue", "fdr"
))
if (nrow(all_results) > 0L && length(all_result_scientific_columns)) {
  addStyle(
    wb, all_results_sheet, scientific_result_style,
    rows = 2:(nrow(all_results) + 1L),
    cols = all_result_scientific_columns,
    gridExpand = TRUE, stack = TRUE
  )
}

generated_sheet_names <- intersect(
  c("Contrast Guide", all_results_sheet), names(wb)
)
generated_sheet_name <- function(prefix, label) {
  base <- trimws(paste(prefix, gsub("_", " ", label)))
  for (character in c("[", "]", "*", "?", ":", "/", "\\")) {
    base <- gsub(character, "-", base, fixed = TRUE)
  }
  base <- substr(base, 1L, 31L)
  candidate <- base
  copy_number <- 2L
  while (candidate %in% generated_sheet_names) {
    suffix <- paste0(" (", copy_number, ")")
    candidate <- paste0(substr(base, 1L, 31L - nchar(suffix)), suffix)
    copy_number <- copy_number + 1L
  }
  generated_sheet_names <<- c(generated_sheet_names, candidate)
  candidate
}

for (label in comparison_order) {
  de <- merge(
    comparisons[
      Label == label & is.finite(adj.pvalue) & adj.pvalue < fdr_cutoff &
        is.finite(log2FC) & abs(log2FC) >= log2fc_cutoff
    ],
    protein_annotation,
    by = "Protein",
    all.x = TRUE,
    sort = FALSE
  )
  setcolorder(de, c("Protein", "GeneSymbol", "Description", setdiff(names(de), c("Protein", "GeneSymbol", "Description"))))
  de[, .abs_log2FC_sort := abs(log2FC)]
  setorder(de, adj.pvalue, -.abs_log2FC_sort)
  de[, .abs_log2FC_sort := NULL]
  replace_sheet(generated_sheet_name("DE", label), as.data.frame(de))
}

for (label in comparison_order) {
  path <- file.path(
    results_dir,
    paste0("gsea_go_bp_", comparison_file_key(label), ".csv")
  )
  gsea <- if (file.exists(path)) data.table::fread(path) else data.frame(Note = "No GSEA result file was produced.")
  replace_sheet(generated_sheet_name("GSEA", label), as.data.frame(gsea))
}

guide <- data.frame(
  Section = c(
    "Source analysis", "Proteins worksheet", "Peptide worksheet",
    "Peptide calculated abundance", "Protein unnormalized abundance",
    "Peptide normalized abundance",
    "Protein normalized abundance", "Group abundance", "Comparison ratio",
    "Contrast Guide", "All MSstats Results", "Differential-expression sheets",
    "GSEA sheets"
  ),
  Definition = c(
    source_analysis_description,
    paste0(
      "Protein-only view containing Master Protein and Master Protein Candidate ",
      "rows from the source workbook. MSstats values are present where the ",
      "source accession exactly matches a modeled master protein."
    ),
    paste0(
      "Hierarchical Proteome Discoverer view containing protein rows, protein ",
      "candidate rows, peptide headers, and peptide rows. Peptide sections retain ",
      "their source grouping and collapsed-row behavior."
    ),
    "Sum of positive PDtoMSstatsFormat feature intensities for a protein-peptide-run across precursor charge states; linear scale.",
    paste0(
      "MSstats ProteinLevelData LogIntensities from a second dataProcess call ",
      "with normalization and model-based imputation disabled, using log2 ",
      "transformation and ", summary_method, " summarization; log2 scale. ",
      "Values occupy protein rows directly above their peptide rows."
    ),
    paste0(
      "Calculated peptide abundance after ", normalization_method,
      " normalization; linear scale."
    ),
    paste0(
      "MSstats ProteinLevelData LogIntensities after ", normalization_method,
      " normalization and ", summary_method, " summarization; log2 scale."
    ),
    paste0(
      "Arithmetic mean of MSstats protein LogIntensities within each condition: ",
      paste(group_order, collapse = ", "), "; log2 scale."
    ),
    paste0(
      "2 raised to the MSstats log2FC. Remaining fields are copied from ",
      "groupComparison, including uncertainty, p-values, missingness, imputation, ",
      "and issue flags. Non-finite values are displayed as NA, Inf, or -Inf so ",
      "Excel does not display numeric error cells."
    ),
    paste0(
      "One row per statistical contrast, with its coefficient formula, plain-language ",
      "meaning, direction of positive and negative estimates, and limitations. The ",
      "same table is exported as msstats_contrast_guide.csv."
    ),
    paste0(
      "Complete MSstats groupComparison output for every modeled protein and every ",
      "contrast. This includes results that cannot be joined to an exact master-protein ",
      "row in the source workbook."
    ),
    paste0(
      "Proteins with adjusted p-value < ", fdr_cutoff,
      " and absolute log2FC >= ", log2fc_cutoff,
      ", one worksheet per contrast."
    ),
    "Complete GO Biological Process GSEA result table produced by the report, one worksheet per contrast."
  ),
  stringsAsFactors = FALSE
)
replace_sheet("MSstats Export Guide", guide)
setColWidths(wb, "MSstats Export Guide", cols = 1, widths = 30)
setColWidths(wb, "MSstats Export Guide", cols = 2, widths = 100)
setRowHeights(wb, "MSstats Export Guide", rows = 2:(nrow(guide) + 1), heights = 36)
addStyle(
  wb, "MSstats Export Guide", createStyle(wrapText = TRUE, valign = "top"),
  rows = 2:(nrow(guide) + 1), cols = 1:2, gridExpand = TRUE, stack = TRUE
)

# Give the complete hierarchical worksheet an unambiguous name, then create a
# compact worksheet that contains only protein and protein-candidate rows.
original_main_sheet <- main_sheet
if (!identical(main_sheet, "Peptide")) {
  if ("Peptide" %in% names(wb)) removeWorksheet(wb, "Peptide")
  renamed_sheets <- names(wb)
  renamed_sheets[match(main_sheet, renamed_sheets)] <- "Peptide"
  names(wb) <- renamed_sheets
  main_sheet <- "Peptide"
}

protein_sheet <- "Proteins"
if (protein_sheet %in% names(wb)) removeWorksheet(wb, protein_sheet)
addWorksheet(wb, protein_sheet)

protein_original_data <- original_table[protein_display_rows, , drop = FALSE]
protein_msstats_data <- new_data[protein_display_rows, , drop = FALSE]
protein_only_headers <- c(
  original_header_values[seq_len(original_last_col)],
  protein_headers
)
writeData(
  wb, protein_sheet, t(protein_only_headers),
  startRow = 1L, startCol = 1L, colNames = FALSE, rowNames = FALSE
)
writeData(
  wb, protein_sheet, protein_original_data,
  startRow = 2L, startCol = 1L, colNames = FALSE, rowNames = FALSE,
  keepNA = FALSE
)
writeData(
  wb, protein_sheet, protein_msstats_data,
  startRow = 2L, startCol = start_col, colNames = FALSE, rowNames = FALSE,
  keepNA = FALSE
)

if (nrow(main_nonfinite_labels)) {
  protein_nonfinite_labels <- main_nonfinite_labels
  protein_nonfinite_labels$row <- match(
    protein_nonfinite_labels$row, protein_display_rows
  ) + 1L
  protein_nonfinite_labels$col <-
    start_col + protein_nonfinite_labels$col - 1L
  protein_nonfinite_labels <- protein_nonfinite_labels[
    !is.na(protein_nonfinite_labels$row), , drop = FALSE
  ]
  write_excel_labels(wb, protein_sheet, protein_nonfinite_labels)
}

addFilter(wb, protein_sheet, rows = 1L, cols = seq_len(last_output_col))
freezePane(wb, protein_sheet, firstActiveRow = 2L, firstActiveCol = 5L)
setColWidths(wb, protein_sheet, cols = 1:original_last_col, widths = 12)
if (length(wide_original_cols)) {
  setColWidths(wb, protein_sheet, cols = wide_original_cols, widths = 40)
}
setColWidths(
  wb, protein_sheet, cols = start_col:last_output_col, widths = 13
)
setRowHeights(wb, protein_sheet, rows = 1L, heights = 135)
protein_only_rows <- seq_len(length(protein_display_rows)) + 1L
setRowHeights(wb, protein_sheet, rows = protein_only_rows, heights = 30)
protein_only_long_rows <- match(long_description_rows, protein_display_rows) + 1L
protein_only_long_rows <- protein_only_long_rows[
  !is.na(protein_only_long_rows)
]
if (length(protein_only_long_rows)) {
  setRowHeights(
    wb, protein_sheet, rows = protein_only_long_rows, heights = 45
  )
}
addStyle(
  wb, protein_sheet, column_header_style,
  rows = 1L, cols = seq_len(last_output_col),
  gridExpand = TRUE, stack = FALSE
)
addStyle(
  wb, protein_sheet, protein_row_style,
  rows = protein_only_rows, cols = seq_len(last_output_col),
  gridExpand = TRUE, stack = FALSE
)
addStyle(
  wb, protein_sheet, protein_number_style,
  rows = protein_only_rows, cols = start_col:last_output_col,
  gridExpand = TRUE, stack = FALSE
)
addStyle(
  wb, protein_sheet, protein_scientific_style,
  rows = protein_only_rows, cols = scientific_protein_cols,
  gridExpand = TRUE, stack = FALSE
)

# openxlsx intentionally resets the worksheet dimension when loading. Restore
# the source report's final row and expand only the final column for the newly
# appended fields so Excel's used range remains accurate.
main_sheet_index <- match(main_sheet, names(wb))
wb$worksheets[[main_sheet_index]]$dimension <- sprintf(
  "<dimension ref=\"A1:%s%d\"/>",
  int2col(start_col + n_new_cols - 1L),
  n_rows + 1L
)
current_sheet_names <- names(wb)
template_other_sheets <- setdiff(template_sheet_order, original_main_sheet)
desired_sheet_order <- c(
  "MSstats Export Guide",
  "Contrast Guide",
  all_results_sheet,
  protein_sheet,
  main_sheet,
  template_other_sheets[template_other_sheets %in% current_sheet_names],
  setdiff(
    current_sheet_names,
    c(
      "MSstats Export Guide", "Contrast Guide", all_results_sheet,
      protein_sheet, main_sheet, template_other_sheets
    )
  )
)
desired_sheet_order <- unique(
  desired_sheet_order[desired_sheet_order %in% current_sheet_names]
)
worksheetOrder(wb) <- match(desired_sheet_order, current_sheet_names)

# Reordering changes the worksheet positions inside the workbook object.
main_sheet_index <- match(main_sheet, names(wb))

# Keep the top header and columns A:D visible, with the first unfrozen cell at
# E2. openxlsx stores an imported worksheet pane in two places, so update both
# to prevent a template's old horizontal scroll position from being restored
# when the workbook is saved.
main_freeze_pane <- paste0(
  "<pane xSplit=\"4\" ySplit=\"1\" topLeftCell=\"E2\" ",
  "activePane=\"bottomRight\" state=\"frozen\"/>"
)
wb$worksheets[[main_sheet_index]]$sheetViews <- paste0(
  "<sheetViews><sheetView workbookViewId=\"0\">",
  main_freeze_pane,
  "<selection pane=\"topRight\" activeCell=\"E1\" sqref=\"E1\"/>",
  "<selection pane=\"bottomLeft\" activeCell=\"A2\" sqref=\"A2\"/>",
  "<selection pane=\"bottomRight\" activeCell=\"E2\" sqref=\"E2\"/>",
  "</sheetView></sheetViews>"
)
wb$worksheets[[main_sheet_index]]$freezePane <- main_freeze_pane

# Some Proteome Discoverer files omit the workbook-window dimensions. Supply
# valid defaults so the finished workbook also opens cleanly outside Excel.
wb$workbook$bookViews <- paste0(
  "<bookViews><workbookView xWindow=\"0\" yWindow=\"0\" ",
  "windowWidth=\"24000\" windowHeight=\"12000\" firstSheet=\"0\" ",
  "activeTab=\"0\"/></bookViews>"
)

# Imported Proteome Discoverer workbooks can contain placeholder drawing and
# comment relationships even when no drawing or comment exists. Remove only
# those empty relationships so other spreadsheet readers do not look for
# nonexistent drawing files. Real drawings or comments are retained.
for (sheet_index in seq_along(wb$worksheets)) {
  has_drawing <- length(wb$drawings) >= sheet_index &&
    length(wb$drawings[[sheet_index]]) > 0L
  has_vml <- (
    length(wb$vml) >= sheet_index && length(wb$vml[[sheet_index]]) > 0L
  ) || (
    length(wb$comments) >= sheet_index && length(wb$comments[[sheet_index]]) > 0L
  )

  if (!has_drawing) {
    wb$worksheets[[sheet_index]]$drawing <- character()
  }
  if (!has_vml) {
    wb$worksheets[[sheet_index]]$legacyDrawing <- character()
  }

  if (length(wb$worksheets_rels) >= sheet_index) {
    relationships <- wb$worksheets_rels[[sheet_index]]
    if (!has_drawing) {
      relationships <- relationships[
        !grepl("relationships/drawing\"", relationships, fixed = TRUE)
      ]
    }
    if (!has_vml) {
      relationships <- relationships[
        !grepl("relationships/vmlDrawing\"", relationships, fixed = TRUE)
      ]
    }
    wb$worksheets_rels[[sheet_index]] <- relationships
  }
}

dir.create(dirname(output_file), recursive = TRUE, showWarnings = FALSE)
saveWorkbook(wb, output_file, overwrite = TRUE)
cat("Saved:", normalizePath(output_file, winslash = "/", mustWork = TRUE), "\n")
cat("Protein rows:", length(protein_rows), "\n")
cat("Protein candidate rows:", length(protein_candidate_rows), "\n")
cat("Peptide rows:", length(peptide_rows), "\n")
cat("Appended columns:", n_new_cols, "\n")
invisible(output_file)
}

if (sys.nframe() == 0L) {
  args <- commandArgs(trailingOnly = TRUE)
  if (length(args) < 3L || length(args) > 4L) {
    stop(
      "Usage: export_msstats_workbook.R <input.xlsx> <msstats_objects.rds> <results_dir> [output.xlsx]",
      call. = FALSE
    )
  }
  do.call(export_msstats_workbook, as.list(args))
}
