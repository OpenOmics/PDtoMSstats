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
