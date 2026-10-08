#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 7L || length(args) > 9L) {
  stop(
    paste(
      "Usage: create_example_subset.R <source-psm> <source-annotation>",
      "<masigpro-results.csv> <output-dir> <source-group-column>",
      "<reference-group> <comparison-group> [interaction-proteins]",
      "[background-proteins]"
    ),
    call. = FALSE
  )
}

required_packages <- c("data.table", "dplyr", "readxl", "readr")
missing_packages <- required_packages[
  !vapply(required_packages, requireNamespace, logical(1), quietly = TRUE)
]
if (length(missing_packages)) {
  stop("Install: ", paste(missing_packages, collapse = ", "), call. = FALSE)
}

source_psm <- normalizePath(args[[1]], winslash = "/", mustWork = TRUE)
source_annotation <- normalizePath(args[[2]], winslash = "/", mustWork = TRUE)
model_file <- normalizePath(args[[3]], winslash = "/", mustWork = TRUE)
output_dir <- args[[4]]
source_group_column <- args[[5]]
reference_group <- args[[6]]
comparison_group <- args[[7]]
interaction_count <- if (length(args) >= 8L) as.integer(args[[8]]) else 60L
background_count <- if (length(args) >= 9L) as.integer(args[[9]]) else 40L

search_tool <- if (nzchar(Sys.which("rg"))) "rg" else "grep"
if (!nzchar(Sys.which(search_tool))) {
  stop("This maintainer utility needs rg or grep to stream the source file.", call. = FALSE)
}
if (!is.finite(interaction_count) || interaction_count < 3L ||
    !is.finite(background_count) || background_count < 1L) {
  stop("Protein subset sizes must be positive integers.", call. = FALSE)
}

dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

annotation_extension <- tolower(tools::file_ext(source_annotation))
annotation <- if (annotation_extension %in% c("xlsx", "xls")) {
  readxl::read_excel(source_annotation, sheet = 1)
} else {
  data.table::fread(source_annotation, data.table = FALSE)
}
required_annotation <- c("File ID", "Time", source_group_column)
missing_annotation <- setdiff(required_annotation, names(annotation))
if (length(missing_annotation)) {
  stop(
    "Source annotation is missing: ",
    paste(missing_annotation, collapse = ", "),
    call. = FALSE
  )
}

model_results <- readr::read_csv(model_file, show_col_types = FALSE)
required_model <- c(
  "Protein", "OverallModelAdjustedPValue", "ModelRSquared",
  "DifferentialTimeInteraction"
)
missing_model <- setdiff(required_model, names(model_results))
if (length(missing_model)) {
  stop(
    "Model result is missing: ", paste(missing_model, collapse = ", "),
    call. = FALSE
  )
}

interaction_proteins <- model_results |>
  dplyr::filter(.data$DifferentialTimeInteraction) |>
  dplyr::arrange(
    .data$OverallModelAdjustedPValue,
    dplyr::desc(.data$ModelRSquared),
    .data$Protein
  ) |>
  dplyr::slice_head(n = interaction_count) |>
  dplyr::pull(.data$Protein)

background_proteins <- model_results |>
  dplyr::filter(!.data$DifferentialTimeInteraction) |>
  dplyr::mutate(
    SelectionPValue = dplyr::coalesce(.data$OverallModelAdjustedPValue, 1)
  ) |>
  dplyr::arrange(
    dplyr::desc(.data$SelectionPValue),
    .data$Protein
  ) |>
  dplyr::slice_head(n = background_count) |>
  dplyr::pull(.data$Protein)

selected_proteins <- unique(c(interaction_proteins, background_proteins))
if (length(selected_proteins) < 4L) {
  stop("Too few proteins were selected for a useful example.", call. = FALSE)
}

selected_annotation <- annotation |>
  dplyr::filter(
    .data[[source_group_column]] %in% c(reference_group, comparison_group)
  ) |>
  dplyr::mutate(
    Group = dplyr::if_else(
      .data[[source_group_column]] == reference_group,
      "Reference",
      "Treatment"
    ),
    GroupOrder = match(.data$Group, c("Reference", "Treatment"))
  ) |>
  dplyr::arrange(.data$Time, .data$GroupOrder, .data[["File ID"]]) |>
  dplyr::mutate(
    OriginalFileID = as.character(.data[["File ID"]]),
    `File ID` = sprintf("RUN%03d", dplyr::row_number()),
    `File Name` = sprintf("Sample_%03d.raw", dplyr::row_number()),
    BioReplicate = sprintf("BR%03d", dplyr::row_number())
  ) |>
  dplyr::select(dplyr::all_of(c(
    "OriginalFileID", "File ID", "File Name", "Time", "Group",
    "BioReplicate"
  )))

pattern_file <- tempfile(pattern = "pdtomsstats-proteins-")
filtered_file <- tempfile(pattern = "pdtomsstats-psm-", fileext = ".tsv")
on.exit(unlink(c(pattern_file, filtered_file)), add = TRUE)
writeLines(selected_proteins, pattern_file, useBytes = TRUE)

search_status <- system2(
  search_tool,
  c("-F", "-f", shQuote(pattern_file), shQuote(source_psm)),
  stdout = filtered_file
)
if (!identical(search_status, 0L)) {
  stop("No matching PSM rows were extracted from the source file.", call. = FALSE)
}

source_names <- names(data.table::fread(
  source_psm, nrows = 0L, data.table = FALSE, check.names = FALSE
))
psm <- data.table::fread(
  filtered_file,
  header = FALSE,
  data.table = TRUE,
  check.names = FALSE,
  showProgress = FALSE
)
if (ncol(psm) != length(source_names)) {
  stop("The extracted PSM rows did not match the source header.", call. = FALSE)
}
data.table::setnames(psm, source_names)

required_psm <- c(
  "Confidence", "Annotated Sequence", "Modifications",
  "Master Protein Accessions", "Charge", "File ID", "Contaminant",
  "Quan Value"
)
missing_psm <- setdiff(required_psm, names(psm))
if (length(missing_psm)) {
  stop("Source PSM is missing: ", paste(missing_psm, collapse = ", "), call. = FALSE)
}

psm <- psm[
  `Master Protein Accessions` %in% selected_proteins &
    `File ID` %in% selected_annotation$OriginalFileID &
    Confidence == "High" &
    (is.na(Contaminant) | Contaminant %in% c(FALSE, "False", "FALSE", "0")) &
    is.finite(as.numeric(`Quan Value`)) & as.numeric(`Quan Value`) > 0,
  ..required_psm
]

protein_map <- data.table::data.table(
  OriginalProtein = sort(unique(psm$`Master Protein Accessions`))
)
protein_map[, SyntheticProtein := sprintf("PROT%04d", .I)]
peptide_map <- data.table::data.table(
  OriginalPeptide = sort(unique(psm$`Annotated Sequence`))
)
peptide_map[, SyntheticPeptide := sprintf("PEPTIDE%06d", .I)]
run_map <- data.table::as.data.table(selected_annotation)[
  , .(OriginalFileID, SyntheticFileID = `File ID`)
]

psm <- protein_map[psm, on = c("OriginalProtein" = "Master Protein Accessions")]
psm <- peptide_map[psm, on = c("OriginalPeptide" = "Annotated Sequence")]
psm <- run_map[psm, on = c("OriginalFileID" = "File ID")]
psm[, `:=`(
  `Master Protein Accessions` = SyntheticProtein,
  `Annotated Sequence` = SyntheticPeptide,
  `File ID` = SyntheticFileID,
  Modifications = "",
  Confidence = "High",
  Contaminant = FALSE,
  `Quan Value` = as.numeric(`Quan Value`)
)]

psm <- psm[
  , .(`Quan Value` = max(`Quan Value`, na.rm = TRUE)),
  by = .(
    Confidence, `Annotated Sequence`, Modifications,
    `Master Protein Accessions`, Charge, `File ID`, Contaminant
  )
]
data.table::setcolorder(psm, required_psm)
data.table::setorder(psm, `File ID`, `Master Protein Accessions`, `Annotated Sequence`, Charge)

public_annotation <- selected_annotation |>
  dplyr::select(dplyr::all_of(c(
    "File ID", "File Name", "Time", "Group", "BioReplicate"
  )))

time_values <- sort(unique(public_annotation$Time))
contrast_table <- do.call(rbind, lapply(time_values, function(time_value) {
  data.frame(
    ContrastType = "pairwise",
    Label = paste0("Treatment_vs_Reference_", time_value, "h"),
    Condition = c(
      paste0(time_value, "h_Treatment"),
      paste0(time_value, "h_Reference")
    ),
    Weight = c(1, -1),
    stringsAsFactors = FALSE
  )
}))

data.table::fwrite(psm, file.path(output_dir, "psm.csv"), na = "")
data.table::fwrite(public_annotation, file.path(output_dir, "annotation.csv"), na = "")
data.table::fwrite(
  contrast_table,
  file.path(output_dir, "contrasts.tsv"),
  sep = "\t",
  na = ""
)

cat("Example PSM rows:", nrow(psm), "\n")
cat("Example proteins:", data.table::uniqueN(psm$`Master Protein Accessions`), "\n")
cat("Example runs:", data.table::uniqueN(psm$`File ID`), "\n")
cat("Output:", normalizePath(output_dir, winslash = "/", mustWork = TRUE), "\n")
