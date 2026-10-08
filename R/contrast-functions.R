validate_contrast_table <- function(contrast_table, allowed_conditions = NULL) {
  required_columns <- c("Label", "Condition", "Weight")
  missing_columns <- setdiff(required_columns, names(contrast_table))
  if (length(missing_columns)) {
    stop(
      "Contrast file is missing required column(s): ",
      paste(missing_columns, collapse = ", "),
      call. = FALSE
    )
  }

  contrast_table <- as.data.frame(contrast_table, stringsAsFactors = FALSE)
  contrast_table$Label <- trimws(as.character(contrast_table$Label))
  contrast_table$Condition <- trimws(as.character(contrast_table$Condition))
  if (!"ContrastType" %in% names(contrast_table)) {
    contrast_table$ContrastType <- "auto"
  }
  contrast_table$ContrastType <- trimws(as.character(contrast_table$ContrastType))
  contrast_table$ContrastType[
    is.na(contrast_table$ContrastType) | !nzchar(contrast_table$ContrastType)
  ] <- "auto"

  original_weight <- contrast_table$Weight
  contrast_table$Weight <- suppressWarnings(as.numeric(original_weight))
  invalid_text <- !is.na(original_weight) & is.na(contrast_table$Weight)
  if (any(invalid_text)) {
    stop("Every contrast Weight must be numeric.", call. = FALSE)
  }
  if (any(
    is.na(contrast_table$Label) | !nzchar(contrast_table$Label) |
      is.na(contrast_table$Condition) | !nzchar(contrast_table$Condition) |
      !is.finite(contrast_table$Weight)
  )) {
    stop("Contrast Label, Condition, and Weight cannot be empty.", call. = FALSE)
  }

  contrast_table <- contrast_table[contrast_table$Weight != 0, , drop = FALSE]
  if (!nrow(contrast_table)) {
    stop("Contrast file does not contain any nonzero weights.", call. = FALSE)
  }
  if (anyDuplicated(contrast_table[c("Label", "Condition")])) {
    stop(
      "Each Label and Condition pair must occur only once in the contrast file.",
      call. = FALSE
    )
  }

  label_order <- unique(contrast_table$Label)
  for (label in label_order) {
    rows <- contrast_table$Label == label
    weights <- contrast_table$Weight[rows]
    types <- unique(contrast_table$ContrastType[rows])
    if (length(types) != 1L) {
      stop("Contrast '", label, "' has more than one ContrastType.", call. = FALSE)
    }
    if (length(weights) < 2L) {
      stop("Contrast '", label, "' needs at least two nonzero terms.", call. = FALSE)
    }
    if (abs(sum(weights)) > 1e-8) {
      stop(
        "Weights for contrast '", label, "' must sum to zero; found ",
        format(sum(weights), digits = 8), ".",
        call. = FALSE
      )
    }
  }

  if (!is.null(allowed_conditions)) {
    unknown_conditions <- setdiff(
      unique(contrast_table$Condition), as.character(allowed_conditions)
    )
    if (length(unknown_conditions)) {
      stop(
        "Contrast condition(s) not found in the processed data: ",
        paste(unknown_conditions, collapse = ", "),
        call. = FALSE
      )
    }
  }

  rownames(contrast_table) <- NULL
  attr(contrast_table, "label_order") <- label_order
  contrast_table
}

read_contrast_file <- function(path, allowed_conditions = NULL) {
  if (!requireNamespace("data.table", quietly = TRUE)) {
    stop("Install the data.table package to read contrast files.", call. = FALSE)
  }
  path <- normalizePath(path, winslash = "/", mustWork = TRUE)
  contrast_table <- data.table::fread(
    path,
    data.table = FALSE,
    check.names = FALSE,
    showProgress = FALSE
  )
  validate_contrast_table(contrast_table, allowed_conditions)
}

contrast_table_to_matrix <- function(contrast_table, conditions = NULL) {
  contrast_table <- validate_contrast_table(contrast_table, conditions)
  label_order <- attr(contrast_table, "label_order")
  if (is.null(conditions)) {
    conditions <- unique(contrast_table$Condition)
  }
  conditions <- as.character(conditions)

  contrast_matrix <- matrix(
    0,
    nrow = length(label_order),
    ncol = length(conditions),
    dimnames = list(label_order, conditions)
  )
  for (row in seq_len(nrow(contrast_table))) {
    contrast_matrix[
      contrast_table$Label[[row]], contrast_table$Condition[[row]]
    ] <- contrast_table$Weight[[row]]
  }
  contrast_matrix
}

contrast_matrix_to_table <- function(contrast_matrix) {
  if (is.null(rownames(contrast_matrix)) || is.null(colnames(contrast_matrix))) {
    stop("Contrast matrix needs row and column names.", call. = FALSE)
  }
  rows <- lapply(seq_len(nrow(contrast_matrix)), function(row_index) {
    weights <- as.numeric(contrast_matrix[row_index, ])
    keep <- is.finite(weights) & weights != 0
    nonzero <- weights[keep]
    contrast_type <- if (
      length(nonzero) == 2L &&
        all(sort(nonzero) == c(-1, 1))
    ) {
      "pairwise"
    } else {
      "weighted_contrast"
    }
    data.frame(
      ContrastType = contrast_type,
      Label = rownames(contrast_matrix)[[row_index]],
      Condition = colnames(contrast_matrix)[keep],
      Weight = nonzero,
      stringsAsFactors = FALSE
    )
  })
  validate_contrast_table(do.call(rbind, rows))
}

format_contrast_term <- function(condition, weight) {
  magnitude <- abs(weight)
  if (abs(magnitude - 1) < 1e-10) {
    return(condition)
  }
  coefficient <- formatC(magnitude, digits = 5, format = "fg", flag = "#")
  coefficient <- sub("[.]?0+$", "", coefficient)
  paste0(coefficient, " x ", condition)
}

contrast_formula <- function(contrast_rows) {
  positive <- contrast_rows[contrast_rows$Weight > 0, , drop = FALSE]
  negative <- contrast_rows[contrast_rows$Weight < 0, , drop = FALSE]
  positive_text <- vapply(
    seq_len(nrow(positive)),
    function(i) format_contrast_term(positive$Condition[[i]], positive$Weight[[i]]),
    character(1)
  )
  negative_text <- vapply(
    seq_len(nrow(negative)),
    function(i) format_contrast_term(negative$Condition[[i]], negative$Weight[[i]]),
    character(1)
  )
  left <- paste(positive_text, collapse = " + ")
  right <- paste(negative_text, collapse = " + ")
  if (length(negative_text) > 1L) right <- paste0("(", right, ")")
  paste(left, "-", right)
}

display_condition <- function(condition) {
  gsub("_", " ", condition, fixed = TRUE)
}

trend_unit_from_label <- function(label) {
  match <- regexec("_per_([0-9.]+)(h|hr|hour|hours)$", label, ignore.case = TRUE)
  fields <- regmatches(label, match)[[1]]
  if (!length(fields)) return(NULL)
  value <- fields[[2]]
  paste(value, if (identical(value, "1")) "hour" else "hours")
}

trend_groups_from_label <- function(label) {
  comparison <- sub("_linear_trend.*$", "", label, ignore.case = TRUE)
  groups <- strsplit(comparison, "_vs_", fixed = TRUE)[[1]]
  if (length(groups) != 2L || any(!nzchar(groups))) {
    return(c("the numerator group", "the denominator group"))
  }
  gsub("_", " ", groups, fixed = TRUE)
}

describe_one_contrast <- function(contrast_rows) {
  label <- contrast_rows$Label[[1]]
  type <- tolower(contrast_rows$ContrastType[[1]])
  type <- gsub("[^a-z0-9]+", "_", type)
  positive_rows <- contrast_rows[contrast_rows$Weight > 0, , drop = FALSE]
  negative_rows <- contrast_rows[contrast_rows$Weight < 0, , drop = FALSE]
  is_simple_pair <- nrow(contrast_rows) == 2L &&
    all(sort(contrast_rows$Weight) == c(-1, 1))

  if (identical(type, "auto")) {
    type <- if (is_simple_pair) "pairwise" else "weighted_contrast"
  }

  positive_condition <- if (nrow(positive_rows) == 1L) {
    display_condition(positive_rows$Condition[[1]])
  } else {
    "the positive-weight conditions"
  }
  negative_condition <- if (nrow(negative_rows) == 1L) {
    display_condition(negative_rows$Condition[[1]])
  } else {
    "the negative-weight conditions"
  }

  if (grepl("difference_in_differences", type, fixed = TRUE)) {
    measure <- paste0(
      "Difference between two time-specific condition differences, using the ",
      "displayed formula. It tests whether the between-group difference at one ",
      "time changed relative to the reference time."
    )
    positive <- paste0(
      "The between-group difference increased in the positive direction relative ",
      "to the reference time."
    )
    negative <- paste0(
      "The between-group difference decreased in the positive direction, or ",
      "increased in the opposite direction, relative to the reference time."
    )
    limitation <- paste0(
      "This is a time-specific interaction test. It does not assume or prove a ",
      "linear trajectory across all time points."
    )
  } else if (grepl("linear_trend", type, fixed = TRUE)) {
    unit <- trend_unit_from_label(label)
    trend_groups <- trend_groups_from_label(label)
    numerator_group <- trend_groups[[1]]
    denominator_group <- trend_groups[[2]]
    unit_text <- if (is.null(unit)) {
      "on the scale used to construct the weights"
    } else {
      paste0("per ", unit)
    }
    measure <- paste0(
      "Difference between the ", numerator_group, " and ", denominator_group,
      " linear time slopes in log2 ",
      "protein abundance, ", unit_text, ". Actual sampling times are represented ",
      "by the weights."
    )
    positive <- paste0(
      "The ", numerator_group, " slope is more positive than the ",
      denominator_group, " slope; their separation tends to increase over time. The ",
      "estimate is the slope difference ", unit_text, "."
    )
    negative <- paste0(
      "The ", numerator_group, " slope is less positive than the ",
      denominator_group, " slope; their separation tends to decrease over time. The ",
      "estimate is the slope difference ", unit_text, "."
    )
    limitation <- paste0(
      "This test detects a linear, unidirectional component. Nonlinear or ",
      "transient trajectories can be missed, and significant proteins should ",
      "be checked with time-profile plots."
    )
  } else if (grepl("time_vs", type, fixed = TRUE)) {
    measure <- paste0(
      "Within-group change in mean log2 protein abundance: ",
      positive_condition, " minus ", negative_condition, "."
    )
    positive <- paste0(positive_condition, " has higher abundance than ", negative_condition, ".")
    negative <- paste0(positive_condition, " has lower abundance than ", negative_condition, ".")
    limitation <- paste0(
      "This includes every time-related change within the group. Use the ",
      "difference-in-differences contrast for an infection-specific change."
    )
  } else if (is_simple_pair || grepl("vs_control_at_time", type, fixed = TRUE)) {
    measure <- paste0(
      "Difference in mean log2 protein abundance: ",
      positive_condition, " minus ", negative_condition, "."
    )
    positive <- paste0(positive_condition, " has higher abundance than ", negative_condition, ".")
    negative <- paste0(positive_condition, " has lower abundance than ", negative_condition, ".")
    limitation <- "The conclusion applies only to the two named conditions."
  } else {
    measure <- paste0(
      "Weighted difference in mean log2 protein abundance using the displayed formula."
    )
    positive <- "The weighted positive side of the formula is larger than the weighted negative side."
    negative <- "The weighted positive side of the formula is smaller than the weighted negative side."
    limitation <- paste0(
      "Interpretation depends on the supplied weights. Confirm that the formula ",
      "matches the intended biological comparison."
    )
  }

  data.frame(
    ContrastType = contrast_rows$ContrastType[[1]],
    Label = label,
    Formula = contrast_formula(contrast_rows),
    WhatItMeasures = measure,
    PositiveEstimate = positive,
    NegativeEstimate = negative,
    NotSignificant = paste0(
      "No statistically supported effect was detected for this contrast. This ",
      "is not evidence that the protein has no biological change."
    ),
    ImportantLimitation = limitation,
    stringsAsFactors = FALSE
  )
}

describe_contrasts <- function(contrast_table) {
  contrast_table <- validate_contrast_table(contrast_table)
  label_order <- attr(contrast_table, "label_order")
  descriptions <- lapply(label_order, function(label) {
    describe_one_contrast(
      contrast_table[contrast_table$Label == label, , drop = FALSE]
    )
  })
  do.call(rbind, descriptions)
}

write_contrast_guide <- function(contrast_table, output_file) {
  if (!requireNamespace("data.table", quietly = TRUE)) {
    stop("Install the data.table package to write the contrast guide.", call. = FALSE)
  }
  guide <- describe_contrasts(contrast_table)
  dir.create(dirname(output_file), recursive = TRUE, showWarnings = FALSE)
  data.table::fwrite(guide, output_file)
  invisible(guide)
}
