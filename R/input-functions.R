read_input_table <- function(file, sheet = 1, n_max = Inf) {
  extension <- tolower(tools::file_ext(file))

  if (extension %in% c("xls", "xlsx")) {
    return(readxl::read_excel(
      file,
      sheet = sheet,
      n_max = n_max,
      .name_repair = "minimal"
    ))
  }

  if (extension %in% c("csv", "tsv", "txt")) {
    return(data.table::fread(
      file,
      nrows = n_max,
      data.table = FALSE,
      check.names = FALSE,
      showProgress = interactive()
    ))
  }

  stop(
    "Unsupported input file type: .", extension,
    ". Use XLS, XLSX, CSV, TSV, or TXT.",
    call. = FALSE
  )
}

config_column <- function(config, name, default) {
  value <- config[[name]]
  if (is.null(value) || length(value) != 1L || is.na(value) ||
      !nzchar(trimws(as.character(value)))) {
    return(default)
  }
  as.character(value)
}

rename_input_columns <- function(data, mapping, description) {
  mapping <- mapping[!is.na(mapping) & nzchar(mapping)]
  duplicated_sources <- unique(unname(mapping)[duplicated(unname(mapping))])
  if (length(duplicated_sources)) {
    stop(
      description, " maps more than one required field to: ",
      paste(duplicated_sources, collapse = ", "),
      call. = FALSE
    )
  }

  missing_sources <- setdiff(unname(mapping), names(data))
  if (length(missing_sources)) {
    stop(
      description, " is missing mapped column(s): ",
      paste(missing_sources, collapse = ", "),
      call. = FALSE
    )
  }

  for (canonical_name in names(mapping)) {
    source_name <- unname(mapping[[canonical_name]])
    if (identical(source_name, canonical_name)) next
    if (canonical_name %in% names(data)) {
      stop(
        description, " contains both the canonical column '", canonical_name,
        "' and its mapped source '", source_name, "'. Keep one of them.",
        call. = FALSE
      )
    }
    names(data)[match(source_name, names(data))] <- canonical_name
  }
  data
}

normalize_psm_columns <- function(data, config) {
  mapping <- c(
    "File ID" = config_column(config, "psm_file_id_column", "File ID"),
    "Annotated Sequence" = config_column(
      config, "psm_sequence_column", "Annotated Sequence"
    ),
    "Charge" = config_column(config, "psm_charge_column", "Charge"),
    "Master Protein Accessions" = config_column(
      config, "psm_protein_column", "Master Protein Accessions"
    ),
    "Quan Value" = config_column(config, "psm_intensity_column", "Quan Value")
  )
  rename_input_columns(data, mapping, "PSM input")
}

normalize_annotation_columns <- function(data, config) {
  mapping <- c(
    "File ID" = config_column(
      config, "annotation_file_id_column", "File ID"
    )
  )

  file_name_column <- config_column(
    config, "annotation_file_name_column", "File Name"
  )
  bioreplicate_column <- config_column(
    config, "annotation_bioreplicate_column", "BioReplicate"
  )
  condition_column <- config_column(
    config, "annotation_condition_column", "Condition"
  )

  file_name_from_file_id <- isTRUE(config$file_name_from_file_id)
  bioreplicate_from_file_id <- isTRUE(config$bioreplicate_from_file_id)

  if (!file_name_from_file_id) mapping[["File Name"]] <- file_name_column
  if (!bioreplicate_from_file_id) mapping[["BioReplicate"]] <- bioreplicate_column

  condition_columns <- as.character(config$condition_columns)
  condition_columns <- condition_columns[
    !is.na(condition_columns) & nzchar(condition_columns)
  ]
  if (!length(condition_columns)) mapping[["Condition"]] <- condition_column

  data <- rename_input_columns(data, mapping, "Annotation input")
  if (file_name_from_file_id) data[["File Name"]] <- as.character(data[["File ID"]])
  if (bioreplicate_from_file_id) {
    data[["BioReplicate"]] <- as.character(data[["File ID"]])
  }
  data
}

make_condition <- function(annotation, condition_columns = NULL,
                           condition_template = NULL,
                           condition_separator = "_") {
  columns <- as.character(condition_columns)
  columns <- columns[!is.na(columns) & nzchar(columns)]

  if (!length(columns)) {
    if (!"Condition" %in% names(annotation)) {
      stop(
        "The annotation needs a Condition column, or condition_columns must be set in the configuration.",
        call. = FALSE
      )
    }
    return(as.character(annotation$Condition))
  }

  missing_columns <- setdiff(columns, names(annotation))
  if (length(missing_columns)) {
    stop(
      "The annotation is missing condition column(s): ",
      paste(missing_columns, collapse = ", "),
      call. = FALSE
    )
  }

  condition_values <- lapply(annotation[columns], as.character)
  incomplete <- Reduce(
    `|`,
    lapply(condition_values, function(value) is.na(value) | !nzchar(trimws(value)))
  )
  if (any(incomplete)) {
    stop("Columns used to create Condition cannot contain empty values.", call. = FALSE)
  }

  has_template <- !is.null(condition_template) &&
    length(condition_template) == 1L &&
    !is.na(condition_template) &&
    nzchar(condition_template)

  if (!has_template) {
    return(do.call(paste, c(condition_values, sep = condition_separator)))
  }

  condition <- vapply(seq_len(nrow(annotation)), function(row) {
    value <- as.character(condition_template)
    for (column in columns) {
      value <- gsub(
        paste0("{", column, "}"),
        as.character(annotation[[column]][[row]]),
        value,
        fixed = TRUE
      )
    }
    value
  }, character(1))

  unused_placeholders <- unique(unlist(regmatches(
    condition,
    gregexpr("\\{[^{}]+\\}", condition, perl = TRUE)
  )))
  if (length(unused_placeholders)) {
    stop(
      "Unknown placeholder(s) in condition_template: ",
      paste(unused_placeholders, collapse = ", "),
      call. = FALSE
    )
  }

  condition
}
