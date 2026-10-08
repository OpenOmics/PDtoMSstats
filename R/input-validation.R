check_msstats_inputs <- function(config_file, repo_root, verbose = TRUE) {
  required_packages <- c("data.table", "readxl", "yaml")
  missing_packages <- required_packages[
    !vapply(required_packages, requireNamespace, logical(1), quietly = TRUE)
  ]
  if (length(missing_packages)) {
    stop(
      "Install required package(s): ", paste(missing_packages, collapse = ", "),
      call. = FALSE
    )
  }

  config_file <- normalizePath(config_file, winslash = "/", mustWork = TRUE)
  repo_root <- normalizePath(repo_root, winslash = "/", mustWork = TRUE)
  source(file.path(repo_root, "R", "contrast-functions.R"), local = TRUE)
  source(file.path(repo_root, "R", "input-functions.R"), local = TRUE)
  config <- yaml::read_yaml(config_file)

  required_settings <- c("request", "psm_file", "annotation_file")
  missing_settings <- required_settings[
    !vapply(required_settings, function(name) {
      value <- config[[name]]
      !is.null(value) && length(value) == 1L && !is.na(value) && nzchar(value)
    }, logical(1))
  ]
  if (length(missing_settings)) {
    stop(
      "Missing configuration setting(s): ",
      paste(missing_settings, collapse = ", "),
      call. = FALSE
    )
  }

  resolve_repo_path <- function(path) {
    candidate <- if (grepl("^(/|[A-Za-z]:[/\\\\])", path)) {
      path
    } else {
      file.path(repo_root, path)
    }
    normalizePath(candidate, winslash = "/", mustWork = TRUE)
  }

  check_input <- function(file, sheet, required_columns, description,
                          read_all = FALSE) {
    extension <- tolower(tools::file_ext(file))
    if (extension %in% c("xls", "xlsx")) {
      sheets <- readxl::excel_sheets(file)
      if (is.numeric(sheet)) {
        if (length(sheet) != 1L || is.na(sheet) || sheet < 1L || sheet > length(sheets)) {
          stop(description, " sheet number is outside the workbook.", call. = FALSE)
        }
      } else if (!as.character(sheet) %in% sheets) {
        stop(
          description, " sheet '", sheet, "' was not found. Available sheets: ",
          paste(sheets, collapse = ", "),
          call. = FALSE
        )
      }
    }

    preview <- read_input_table(
      file, sheet = sheet, n_max = if (read_all) Inf else 1
    )
    missing_columns <- setdiff(required_columns, names(preview))
    if (length(missing_columns)) {
      stop(
        description, " is missing required column(s): ",
        paste(missing_columns, collapse = ", "),
        call. = FALSE
      )
    }

    if (verbose) {
      cat(description, ":", file, "\n")
      if (extension %in% c("xls", "xlsx")) {
        cat("  Sheet:", if (is.numeric(sheet)) sheets[[sheet]] else sheet, "\n")
      } else {
        cat("  Format:", toupper(extension), "\n")
      }
      cat("  Required columns: present\n")
    }

    preview
  }

  psm_file <- resolve_repo_path(config$psm_file)
  annotation_file <- resolve_repo_path(config$annotation_file)
  psm_sheet <- if (is.null(config$psm_sheet)) "PSMs" else config$psm_sheet
  annotation_sheet <- if (is.null(config$annotation_sheet)) 1 else config$annotation_sheet

  check_input(
    psm_file,
    psm_sheet,
    c("File ID", "Annotated Sequence", "Charge", "Master Protein Accessions", "Quan Value"),
    "PSM input"
  )
  condition_columns <- as.character(config$condition_columns)
  condition_columns <- condition_columns[!is.na(condition_columns) & nzchar(condition_columns)]
  annotation_required <- c("File Name", "File ID", "BioReplicate")
  if (length(condition_columns)) {
    annotation_required <- c(annotation_required, condition_columns)
  } else {
    annotation_required <- c(annotation_required, "Condition")
  }
  annotation_preview <- check_input(
    annotation_file,
    annotation_sheet,
    annotation_required,
    "Annotation input",
    read_all = TRUE
  )
  annotation_conditions <- make_condition(
    annotation_preview,
    condition_columns = condition_columns,
    condition_template = config$condition_template,
    condition_separator = if (is.null(config$condition_separator)) "_" else config$condition_separator
  )
  if (verbose) {
    cat("  Conditions:", length(unique(annotation_conditions)), "\n")
    cat("  Condition names:", paste(unique(annotation_conditions), collapse = ", "), "\n")
  }

  has_contrast_file <- !is.null(config$contrast_file) &&
    length(config$contrast_file) == 1L &&
    !is.na(config$contrast_file) &&
    nzchar(config$contrast_file)
  if (has_contrast_file) {
    contrast_file <- resolve_repo_path(config$contrast_file)
    contrast_table <- read_contrast_file(contrast_file)
    missing_contrast_conditions <- setdiff(
      unique(contrast_table$Condition), unique(annotation_conditions)
    )
    if (length(missing_contrast_conditions)) {
      stop(
        "Contrast conditions not found in the annotation design: ",
        paste(missing_contrast_conditions, collapse = ", "),
        call. = FALSE
      )
    }
    if (verbose) {
      cat("Contrast file:", contrast_file, "\n")
      cat("  Contrasts:", length(unique(contrast_table$Label)), "\n")
      cat("  Weights and labels: valid\n")
    }
  }

  if (verbose) cat("Input check: PASS\n")
  invisible(config)
}
