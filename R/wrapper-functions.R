`%||%` <- function(value, fallback) {
  if (is.null(value) || !length(value)) fallback else value
}

pdt_is_set <- function(value) {
  !is.null(value) && length(value) > 0L &&
    any(!is.na(value) & nzchar(trimws(as.character(value))))
}

pdt_split_values <- function(value) {
  if (!pdt_is_set(value)) return(character())
  values <- unlist(strsplit(as.character(value), ",", fixed = TRUE), use.names = FALSE)
  values <- trimws(values)
  unique(values[!is.na(values) & nzchar(values)])
}

pdt_option_spec <- function() {
  value_options <- c(
    "config", "psm", "psm-sheet", "annotation", "annotation-sheet",
    "request", "label", "output-dir", "figures-dir", "outputs",
    "condition-columns", "condition-template", "condition-separator",
    "contrast-file", "protein-workbook", "excel-output",
    "organism-package", "cores", "filter-confidence", "normalization",
    "summary-method", "de-pvalue-cutoff", "de-log2fc-cutoff",
    "maximum-allowed-fold-change",
    "gsea-pvalue-cutoff",
    "psm-file-id-column", "psm-sequence-column",
    "psm-charge-column", "psm-protein-column", "psm-intensity-column",
    "annotation-file-name-column", "annotation-file-id-column",
    "bioreplicate-column", "condition-column", "extra-qmd",
    "report-template", "timecourse-config", "time-column", "group-column",
    "reference-group", "comparison-group", "time-unit", "min-replicates",
    "polynomial-degree", "spline-df", "model-fdr",
    "limma-interaction-fdr", "coefficient-alpha",
    "min-r-squared", "min-clusters", "max-clusters",
    "cluster-diagnostic-repeats", "core-membership",
    "timecourse-extra-qmd", "timecourse-template"
  )
  boolean_options <- c(
    "dry-run", "non-interactive", "gsea", "no-gsea",
    "remove-few-measurements", "keep-few-measurements",
    "file-name-from-file-id", "bioreplicate-from-file-id",
    "with-dependencies", "help"
  )
  list(values = value_options, booleans = boolean_options)
}

pdt_parse_cli <- function(args) {
  command <- "run"
  if (length(args) && !startsWith(args[[1]], "-")) {
    command <- tolower(args[[1]])
    args <- args[-1]
  }
  if (!command %in% c("run", "help")) {
    stop("Unknown command: ", command, ". Use 'pdtomsstats help'.", call. = FALSE)
  }

  spec <- pdt_option_spec()
  options <- list()
  provided <- character()
  repeatable <- c("extra-qmd", "timecourse-extra-qmd")
  aliases <- c("h" = "help")

  index <- 1L
  while (index <= length(args)) {
    argument <- args[[index]]
    if (!startsWith(argument, "-")) {
      stop("Unexpected argument: ", argument, call. = FALSE)
    }

    if (startsWith(argument, "--")) {
      option_text <- substring(argument, 3L)
    } else {
      option_text <- substring(argument, 2L)
    }

    inline_value <- NULL
    if (grepl("=", option_text, fixed = TRUE)) {
      split_at <- regexpr("=", option_text, fixed = TRUE)[[1]]
      inline_value <- substring(option_text, split_at + 1L)
      option_text <- substring(option_text, 1L, split_at - 1L)
    }
    option_name <- if (option_text %in% names(aliases)) {
      unname(aliases[[option_text]])
    } else {
      option_text
    }

    if (option_name %in% spec$booleans) {
      if (!is.null(inline_value)) {
        stop("--", option_name, " does not take a value.", call. = FALSE)
      }
      value <- TRUE
    } else if (option_name %in% spec$values) {
      if (is.null(inline_value)) {
        index <- index + 1L
        if (index > length(args) || startsWith(args[[index]], "--")) {
          stop("--", option_name, " requires a value.", call. = FALSE)
        }
        value <- args[[index]]
      } else {
        value <- inline_value
      }
    } else {
      stop("Unknown option: --", option_name, call. = FALSE)
    }

    key <- gsub("-", "_", option_name, fixed = TRUE)
    if (option_name %in% repeatable) {
      options[[key]] <- c(options[[key]], value)
    } else {
      options[[key]] <- value
    }
    provided <- c(provided, key)
    index <- index + 1L
  }

  if (isTRUE(options$no_gsea)) options$run_gsea <- FALSE
  if (isTRUE(options$gsea)) options$run_gsea <- TRUE
  if (isTRUE(options$remove_few_measurements)) {
    options$remove_few_measurements_value <- TRUE
  }
  if (isTRUE(options$keep_few_measurements)) {
    options$remove_few_measurements_value <- FALSE
  }

  list(
    command = command,
    options = options,
    provided = unique(provided)
  )
}

pdt_main_defaults <- function() {
  list(
    request = NULL,
    report_label = NULL,
    psm_file = NULL,
    psm_sheet = "PSMs",
    psm_file_id_column = "File ID",
    psm_sequence_column = "Annotated Sequence",
    psm_charge_column = "Charge",
    psm_protein_column = "Master Protein Accessions",
    psm_intensity_column = "Quan Value",
    annotation_file = NULL,
    annotation_sheet = 1,
    annotation_file_name_column = "File Name",
    annotation_file_id_column = "File ID",
    annotation_bioreplicate_column = "BioReplicate",
    annotation_condition_column = "Condition",
    file_name_from_file_id = FALSE,
    bioreplicate_from_file_id = FALSE,
    condition_columns = NULL,
    condition_template = NULL,
    condition_separator = "_",
    output_dir = NULL,
    figures_dir = NULL,
    contrast_strategy = "all_pairwise",
    contrasts = NULL,
    weighted_contrasts = NULL,
    contrast_file = NULL,
    excluded_runs = NULL,
    organism_package = "org.Hs.eg.db",
    run_gsea = TRUE,
    max_psm_rows = NULL,
    filter_confidence = "High",
    remove_contaminants = TRUE,
    remove_shared_peptides = TRUE,
    remove_single_peptide_proteins = FALSE,
    remove_few_measurements = FALSE,
    normalization = "equalizeMedians",
    summary_method = "TMP",
    mb_impute = TRUE,
    number_of_cores = 1,
    volcano_p_cutoff = 0.05,
    volcano_fc_cutoff = 1,
    differential_pvalue_cutoff = NULL,
    differential_log2fc_cutoff = NULL,
    maximum_allowed_fold_change = 100,
    volcano_top_labels = 10,
    volcano_split_axis_quantile = 0.95,
    volcano_split_axis_min_ratio = 1.8,
    volcano_split_axis_scales = 0.35,
    qc_max_features = 5000,
    qc_max_plot_rows = 250000,
    qc_top_cv_proteins = 25,
    power_alpha = 0.05,
    power_target = 0.8,
    power_effect_log2fc = 1,
    power_top_rows = 200,
    gsea_pvalue_cutoff = 0.05,
    gsea_min_gene_set_size = 100,
    gsea_max_gene_set_size = 500,
    gsea_dot_show_categories = 10,
    gsea_tree_show_categories = 20,
    gsea_tree_label_wrap = 40,
    extra_qmd = NULL,
    report_template = NULL
  )
}

pdt_timecourse_defaults <- function() {
  list(
    analysis_file = NULL,
    request = NULL,
    report_label = NULL,
    output_dir = NULL,
    figures_dir = NULL,
    time_column = NULL,
    group_column = NULL,
    reference_group = NULL,
    comparison_group = NULL,
    time_unit = 24,
    min_replicates_per_cell = 4,
    polynomial_degree = 3,
    spline_df = 3,
    model_fdr = 0.05,
    limma_interaction_fdr = 0.05,
    coefficient_alpha = 0.05,
    min_r_squared = 0.60,
    min_clusters = 2,
    max_clusters = 10,
    cluster_diagnostic_repeats = 20,
    core_membership = 0.70,
    random_seed = 20261007,
    extra_qmd = NULL,
    report_template = NULL
  )
}

pdt_normalize_key <- function(value) {
  tolower(gsub("[^A-Za-z0-9]+", "", value))
}

pdt_match_column <- function(columns, label, aliases, explicit = NULL,
                             required = TRUE) {
  if (pdt_is_set(explicit)) {
    explicit <- as.character(explicit)[[1]]
    if (explicit %in% columns) return(explicit)
    matches <- which(pdt_normalize_key(columns) == pdt_normalize_key(explicit))
    if (length(matches) == 1L) return(columns[[matches]])
    stop(label, " column was not found: ", explicit, call. = FALSE)
  }

  for (alias in aliases) {
    if (alias %in% columns) return(alias)
    matches <- which(pdt_normalize_key(columns) == pdt_normalize_key(alias))
    if (length(matches) == 1L) return(columns[[matches]])
  }
  if (required) {
    stop(
      "Could not identify the ", label, " column. Available columns: ",
      paste(columns, collapse = ", "),
      call. = FALSE
    )
  }
  NULL
}

pdt_psm_aliases <- function() {
  list(
    psm_file_id_column = c("File ID", "FileID", "Run", "Spectrum File", "SpectrumFile"),
    psm_sequence_column = c(
      "Annotated Sequence", "Modified Sequence", "Peptide Sequence", "Sequence"
    ),
    psm_charge_column = c("Charge", "Precursor Charge", "PrecursorCharge"),
    psm_protein_column = c(
      "Master Protein Accessions", "Protein Accessions", "Protein Accession",
      "Protein", "Accession"
    ),
    psm_intensity_column = c(
      "Quan Value", "Abundance", "Intensity", "Reporter Intensity"
    )
  )
}

pdt_annotation_aliases <- function() {
  list(
    annotation_file_id_column = c(
      "File ID", "FileID", "Run", "Spectrum File", "SpectrumFile"
    ),
    annotation_file_name_column = c(
      "File Name", "FileName", "Filename", "Raw File", "RawFile", "Sample Name"
    ),
    annotation_bioreplicate_column = c(
      "BioReplicate", "Biological Replicate", "BiologicalReplicate",
      "Bio Replicate", "Replicate", "SampleID"
    ),
    annotation_condition_column = c("Condition", "Experimental Condition")
  )
}

pdt_resolve_path <- function(path, base_dir, must_work = TRUE) {
  if (!pdt_is_set(path)) return(NULL)
  path <- path.expand(as.character(path)[[1]])
  candidate <- if (grepl("^(/|[A-Za-z]:[/\\\\])", path)) {
    path
  } else {
    file.path(base_dir, path)
  }
  normalizePath(candidate, winslash = "/", mustWork = must_work)
}

pdt_sheet_value <- function(value) {
  if (is.numeric(value)) return(value)
  value <- as.character(value)[[1]]
  numeric_value <- suppressWarnings(as.integer(value))
  if (!is.na(numeric_value) && identical(as.character(numeric_value), value)) {
    numeric_value
  } else {
    value
  }
}

pdt_slug <- function(value) {
  value <- tools::file_path_sans_ext(basename(as.character(value)))
  value <- gsub("[^A-Za-z0-9._-]+", "-", value)
  value <- gsub("^-+|-+$", "", value)
  if (!nzchar(value)) "pdtomsstats-analysis" else value
}

pdt_prompt <- function(question, default = NULL, required = FALSE) {
  default_text <- if (pdt_is_set(default)) paste0(" [", default, "]") else ""
  repeat {
    answer <- trimws(readline(paste0(question, default_text, ": ")))
    if (!nzchar(answer) && pdt_is_set(default)) answer <- as.character(default)[[1]]
    if (nzchar(answer) || !required) return(answer)
    cat("A value is required.\n")
  }
}

pdt_prompt_yes_no <- function(question, default = TRUE) {
  marker <- if (default) "Y/n" else "y/N"
  repeat {
    answer <- tolower(trimws(readline(paste0(question, " [", marker, "]: "))))
    if (!nzchar(answer)) return(default)
    if (answer %in% c("y", "yes")) return(TRUE)
    if (answer %in% c("n", "no")) return(FALSE)
    cat("Enter y or n.\n")
  }
}

pdt_prompt_column <- function(question, columns, default = NULL) {
  cat("\nAvailable columns:\n")
  for (index in seq_along(columns)) {
    cat(sprintf("  %d. %s\n", index, columns[[index]]))
  }
  answer <- pdt_prompt(question, default = default, required = TRUE)
  number <- suppressWarnings(as.integer(answer))
  if (!is.na(number) && number >= 1L && number <= length(columns)) {
    return(columns[[number]])
  }
  pdt_match_column(columns, question, aliases = answer, explicit = answer)
}

pdt_numeric <- function(value, label, integer = FALSE, minimum = NULL,
                        maximum = NULL) {
  number <- suppressWarnings(if (integer) as.integer(value) else as.numeric(value))
  if (length(number) != 1L || is.na(number) || !is.finite(number)) {
    stop(label, " must be a finite number.", call. = FALSE)
  }
  if (!is.null(minimum) && number < minimum) {
    stop(label, " must be at least ", minimum, ".", call. = FALSE)
  }
  if (!is.null(maximum) && number > maximum) {
    stop(label, " must be at most ", maximum, ".", call. = FALSE)
  }
  number
}

pdt_resolve_outputs <- function(options, interactive_allowed) {
  if (pdt_is_set(options$outputs)) {
    outputs <- pdt_split_values(options$outputs)
  } else if (interactive_allowed) {
    outputs <- pdt_split_values(pdt_prompt(
      "Outputs (html, excel, timecourse; comma-separated)", "html"
    ))
  } else {
    outputs <- "html"
  }
  if ("all" %in% tolower(outputs)) outputs <- c("html", "excel", "timecourse")
  outputs <- unique(tolower(outputs))
  unsupported <- setdiff(outputs, c("html", "excel", "timecourse"))
  if (!length(outputs) || length(unsupported)) {
    stop(
      "Outputs must be html, excel, timecourse, or all. Invalid: ",
      paste(unsupported, collapse = ", "),
      call. = FALSE
    )
  }
  outputs
}

pdt_plan_main_analysis <- function(outputs, analysis_file,
                                   with_dependencies = FALSE) {
  dependent_outputs <- intersect(outputs, c("excel", "timecourse"))
  main_analysis_requested <- "html" %in% outputs
  missing_analysis_dependency <- length(dependent_outputs) > 0L &&
    !file.exists(analysis_file)
  run_main_analysis <- main_analysis_requested ||
    (isTRUE(with_dependencies) && missing_analysis_dependency)

  if (missing_analysis_dependency && !run_main_analysis) {
    stop(
      "Requested ", paste(dependent_outputs, collapse = " and "),
      " output requires the existing main-analysis file: ", analysis_file,
      ". Run --outputs html first or add --with-dependencies.",
      call. = FALSE
    )
  }

  list(
    run = run_main_analysis,
    action = if (run_main_analysis) "run" else "reuse"
  )
}

pdt_read_config <- function(path, base_dir) {
  if (!pdt_is_set(path)) return(list())
  config_file <- pdt_resolve_path(path, base_dir, must_work = TRUE)
  config <- yaml::read_yaml(config_file)
  if (!is.list(config)) stop("Configuration must contain a YAML mapping.", call. = FALSE)
  config
}

pdt_apply_cli_to_main <- function(config, options, provided) {
  mapping <- c(
    psm = "psm_file",
    psm_sheet = "psm_sheet",
    annotation = "annotation_file",
    annotation_sheet = "annotation_sheet",
    request = "request",
    label = "report_label",
    output_dir = "output_dir",
    figures_dir = "figures_dir",
    condition_template = "condition_template",
    condition_separator = "condition_separator",
    contrast_file = "contrast_file",
    organism_package = "organism_package",
    cores = "number_of_cores",
    filter_confidence = "filter_confidence",
    normalization = "normalization",
    summary_method = "summary_method",
    de_pvalue_cutoff = "differential_pvalue_cutoff",
    de_log2fc_cutoff = "differential_log2fc_cutoff",
    maximum_allowed_fold_change = "maximum_allowed_fold_change",
    gsea_pvalue_cutoff = "gsea_pvalue_cutoff",
    psm_file_id_column = "psm_file_id_column",
    psm_sequence_column = "psm_sequence_column",
    psm_charge_column = "psm_charge_column",
    psm_protein_column = "psm_protein_column",
    psm_intensity_column = "psm_intensity_column",
    annotation_file_name_column = "annotation_file_name_column",
    annotation_file_id_column = "annotation_file_id_column",
    bioreplicate_column = "annotation_bioreplicate_column",
    condition_column = "annotation_condition_column",
    report_template = "report_template"
  )
  for (source_name in intersect(names(mapping), provided)) {
    config[[unname(mapping[[source_name]])]] <- options[[source_name]]
  }
  if ("condition_columns" %in% provided) {
    config$condition_columns <- pdt_split_values(options$condition_columns)
  }
  if ("extra_qmd" %in% provided) config$extra_qmd <- options$extra_qmd
  if ("run_gsea" %in% names(options)) config$run_gsea <- options$run_gsea
  if ("remove_few_measurements_value" %in% names(options)) {
    config$remove_few_measurements <- options$remove_few_measurements_value
  }
  if ("file_name_from_file_id" %in% provided) {
    config$file_name_from_file_id <- TRUE
  }
  if ("bioreplicate_from_file_id" %in% provided) {
    config$bioreplicate_from_file_id <- TRUE
  }
  config
}

pdt_prepare_main_config <- function(options, provided, project_root,
                                    interactive_allowed = FALSE) {
  user_config <- pdt_read_config(options$config, project_root)
  config <- utils::modifyList(pdt_main_defaults(), user_config)
  config <- pdt_apply_cli_to_main(config, options, provided)
  explicit_fields <- unique(c(names(user_config), provided))

  if (!pdt_is_set(config$psm_file) && interactive_allowed) {
    config$psm_file <- pdt_prompt("PSM file", required = TRUE)
  }
  if (!pdt_is_set(config$annotation_file) && interactive_allowed) {
    config$annotation_file <- pdt_prompt("Annotation file", required = TRUE)
  }
  if (!pdt_is_set(config$psm_file) || !pdt_is_set(config$annotation_file)) {
    stop(
      "Supply --psm and --annotation, or provide --config.",
      call. = FALSE
    )
  }

  config$psm_file <- pdt_resolve_path(config$psm_file, project_root, TRUE)
  config$annotation_file <- pdt_resolve_path(
    config$annotation_file, project_root, TRUE
  )
  config$psm_sheet <- pdt_sheet_value(config$psm_sheet)
  config$annotation_sheet <- pdt_sheet_value(config$annotation_sheet)

  if (!pdt_is_set(config$request)) config$request <- pdt_slug(config$psm_file)
  config$request <- pdt_slug(config$request)
  if (!pdt_is_set(config$report_label)) config$report_label <- config$request
  if (interactive_allowed && !"request" %in% explicit_fields) {
    config$request <- pdt_slug(pdt_prompt("Short project name", config$request, TRUE))
  }
  if (interactive_allowed && !"label" %in% provided &&
      !"report_label" %in% names(user_config)) {
    config$report_label <- pdt_prompt(
      "Report title", config$report_label, required = TRUE
    )
  }

  if (!pdt_is_set(config$output_dir)) {
    config$output_dir <- file.path("results", config$request)
  }
  if (!pdt_is_set(config$figures_dir)) {
    config$figures_dir <- file.path("figures", config$request)
  }
  if (interactive_allowed && !"output_dir" %in% explicit_fields) {
    config$output_dir <- pdt_prompt("Results directory", config$output_dir, TRUE)
  }
  config$output_dir <- pdt_resolve_path(config$output_dir, project_root, FALSE)
  config$figures_dir <- pdt_resolve_path(config$figures_dir, project_root, FALSE)

  psm_header <- read_input_table(
    config$psm_file, sheet = config$psm_sheet, n_max = 0
  )
  annotation_header <- read_input_table(
    config$annotation_file, sheet = config$annotation_sheet, n_max = 0
  )
  psm_aliases <- pdt_psm_aliases()
  psm_labels <- c(
    psm_file_id_column = "PSM file identifier",
    psm_sequence_column = "PSM peptide sequence",
    psm_charge_column = "PSM charge",
    psm_protein_column = "PSM protein accession",
    psm_intensity_column = "PSM quantitative value"
  )
  for (field in names(psm_aliases)) {
    explicit <- if (field %in% explicit_fields) config[[field]] else NULL
    config[[field]] <- pdt_match_column(
      names(psm_header), psm_labels[[field]], psm_aliases[[field]], explicit
    )
  }

  annotation_aliases <- pdt_annotation_aliases()
  explicit_file_id <- if (
    "annotation_file_id_column" %in% explicit_fields
  ) config$annotation_file_id_column else NULL
  config$annotation_file_id_column <- pdt_match_column(
    names(annotation_header), "annotation file identifier",
    annotation_aliases$annotation_file_id_column, explicit_file_id
  )

  if (!isTRUE(config$file_name_from_file_id)) {
    explicit_file_name <- if (
      "annotation_file_name_column" %in% explicit_fields
    ) config$annotation_file_name_column else NULL
    file_name_match <- pdt_match_column(
      names(annotation_header), "annotation file name",
      annotation_aliases$annotation_file_name_column,
      explicit = explicit_file_name,
      required = !is.null(explicit_file_name)
    )
    if (is.null(file_name_match)) {
      config$file_name_from_file_id <- TRUE
      cat("File Name was not found; File ID will be used for sample labels.\n")
    } else {
      config$annotation_file_name_column <- file_name_match
    }
  }

  if (!isTRUE(config$bioreplicate_from_file_id)) {
    explicit_bioreplicate <- if (
      "annotation_bioreplicate_column" %in% explicit_fields ||
        "bioreplicate_column" %in% explicit_fields
    ) config$annotation_bioreplicate_column else NULL
    bioreplicate_match <- pdt_match_column(
      names(annotation_header), "annotation biological replicate",
      annotation_aliases$annotation_bioreplicate_column,
      explicit = explicit_bioreplicate,
      required = !is.null(explicit_bioreplicate)
    )
    if (is.null(bioreplicate_match)) {
      config$bioreplicate_from_file_id <- TRUE
      cat("BioReplicate was not found; File ID will be used for independent samples.\n")
    } else {
      config$annotation_bioreplicate_column <- bioreplicate_match
    }
  }

  condition_columns <- as.character(config$condition_columns)
  condition_columns <- condition_columns[
    !is.na(condition_columns) & nzchar(condition_columns)
  ]
  if (!length(condition_columns)) {
    explicit_condition <- if (
      "annotation_condition_column" %in% explicit_fields ||
        "condition_column" %in% explicit_fields
    ) config$annotation_condition_column else NULL
    condition_match <- pdt_match_column(
      names(annotation_header), "annotation condition",
      annotation_aliases$annotation_condition_column,
      explicit = explicit_condition,
      required = !is.null(explicit_condition)
    )
    if (is.null(condition_match) && interactive_allowed) {
      answer <- pdt_prompt(
        paste0(
          "Columns used to construct Condition (comma-separated; available: ",
          paste(names(annotation_header), collapse = ", "), ")"
        ),
        required = TRUE
      )
      condition_columns <- pdt_split_values(answer)
      config$condition_columns <- condition_columns
      if (!pdt_is_set(config$condition_template)) {
        placeholder_default <- paste0("{", condition_columns, "}", collapse = "_")
        config$condition_template <- pdt_prompt(
          "Condition template", placeholder_default, required = TRUE
        )
      }
    } else if (is.null(condition_match)) {
      stop(
        "No Condition column was found. Supply --condition-columns and, if needed, ",
        "--condition-template.",
        call. = FALSE
      )
    } else {
      config$annotation_condition_column <- condition_match
    }
  } else {
    missing_condition_columns <- setdiff(condition_columns, names(annotation_header))
    if (length(missing_condition_columns)) {
      stop(
        "Condition-building column(s) not found: ",
        paste(missing_condition_columns, collapse = ", "),
        call. = FALSE
      )
    }
    config$condition_columns <- condition_columns
  }

  annotation <- read_input_table(
    config$annotation_file, sheet = config$annotation_sheet
  )
  annotation <- normalize_annotation_columns(annotation, config)
  annotation$Condition <- make_condition(
    annotation,
    condition_columns = config$condition_columns,
    condition_template = config$condition_template,
    condition_separator = config$condition_separator
  )
  condition_names <- unique(as.character(annotation$Condition))
  cat("Conditions: ", paste(condition_names, collapse = ", "), "\n", sep = "")

  if (pdt_is_set(config$contrast_file)) {
    config$contrast_file <- pdt_resolve_path(config$contrast_file, project_root, TRUE)
  }
  if (pdt_is_set(config$extra_qmd)) {
    config$extra_qmd <- vapply(
      as.character(config$extra_qmd),
      pdt_resolve_path,
      character(1),
      base_dir = project_root,
      must_work = TRUE
    )
  }
  if (pdt_is_set(config$report_template)) {
    config$report_template <- pdt_resolve_path(
      config$report_template, project_root, TRUE
    )
  }

  config$number_of_cores <- pdt_numeric(
    config$number_of_cores, "number_of_cores", integer = TRUE, minimum = 1
  )
  config$volcano_p_cutoff <- pdt_numeric(
    config$volcano_p_cutoff, "volcano_p_cutoff", minimum = 0, maximum = 1
  )
  config$volcano_fc_cutoff <- pdt_numeric(
    config$volcano_fc_cutoff, "volcano_fc_cutoff", minimum = 0
  )
  config$differential_pvalue_cutoff <- if (
    pdt_is_set(config$differential_pvalue_cutoff)
  ) {
    pdt_numeric(
      config$differential_pvalue_cutoff,
      "differential_pvalue_cutoff",
      minimum = 0,
      maximum = 1
    )
  } else {
    config$volcano_p_cutoff
  }
  config$differential_log2fc_cutoff <- if (
    pdt_is_set(config$differential_log2fc_cutoff)
  ) {
    pdt_numeric(
      config$differential_log2fc_cutoff,
      "differential_log2fc_cutoff",
      minimum = 0
    )
  } else {
    config$volcano_fc_cutoff
  }
  config$gsea_pvalue_cutoff <- pdt_numeric(
    config$gsea_pvalue_cutoff,
    "gsea_pvalue_cutoff",
    minimum = 0,
    maximum = 1
  )
  config$maximum_allowed_fold_change <- pdt_numeric(
    config$maximum_allowed_fold_change,
    "maximum_allowed_fold_change", minimum = 1
  )
  config$qc_max_plot_rows <- pdt_numeric(
    config$qc_max_plot_rows, "qc_max_plot_rows", integer = TRUE, minimum = 1000
  )
  list(config = config, annotation = annotation, conditions = condition_names)
}

pdt_apply_cli_to_timecourse <- function(config, options, provided) {
  mapping <- c(
    time_column = "time_column",
    group_column = "group_column",
    reference_group = "reference_group",
    comparison_group = "comparison_group",
    time_unit = "time_unit",
    min_replicates = "min_replicates_per_cell",
    polynomial_degree = "polynomial_degree",
    spline_df = "spline_df",
    model_fdr = "model_fdr",
    limma_interaction_fdr = "limma_interaction_fdr",
    coefficient_alpha = "coefficient_alpha",
    min_r_squared = "min_r_squared",
    min_clusters = "min_clusters",
    max_clusters = "max_clusters",
    cluster_diagnostic_repeats = "cluster_diagnostic_repeats",
    core_membership = "core_membership",
    timecourse_template = "report_template"
  )
  for (source_name in intersect(names(mapping), provided)) {
    config[[unname(mapping[[source_name]])]] <- options[[source_name]]
  }
  if ("timecourse_extra_qmd" %in% provided) {
    config$extra_qmd <- options$timecourse_extra_qmd
  }
  config
}

pdt_prepare_timecourse_config <- function(main_config, annotation, options,
                                          provided, project_root,
                                          interactive_allowed = FALSE) {
  user_config <- pdt_read_config(options$timecourse_config, project_root)
  config <- utils::modifyList(pdt_timecourse_defaults(), user_config)
  config <- pdt_apply_cli_to_timecourse(config, options, provided)

  config$analysis_file <- file.path(
    main_config$output_dir, "msstats_workbook_export_objects.rds"
  )
  if (!pdt_is_set(config$request)) {
    config$request <- paste0(main_config$request, "-timecourse")
  }
  config$request <- pdt_slug(config$request)
  if (!pdt_is_set(config$report_label)) {
    config$report_label <- paste(main_config$report_label, "time-course analysis")
  }
  if (!pdt_is_set(config$output_dir)) {
    config$output_dir <- file.path(main_config$output_dir, "timecourse")
  }
  if (!pdt_is_set(config$figures_dir)) {
    config$figures_dir <- file.path(main_config$figures_dir, "timecourse")
  }
  config$output_dir <- pdt_resolve_path(config$output_dir, project_root, FALSE)
  config$figures_dir <- pdt_resolve_path(config$figures_dir, project_root, FALSE)

  columns <- names(annotation)
  if (!pdt_is_set(config$time_column)) {
    detected_time <- pdt_match_column(
      columns, "time-course time", c("Time", "TimePoint", "Hours", "Hour", "Day", "Days"),
      required = FALSE
    )
    config$time_column <- if (!is.null(detected_time)) {
      detected_time
    } else if (interactive_allowed) {
      pdt_prompt_column("Time column", columns)
    } else {
      stop("Supply --time-column for time-course analysis.", call. = FALSE)
    }
  }
  if (!pdt_is_set(config$group_column)) {
    detected_group <- pdt_match_column(
      columns, "time-course group", c("Group", "Treatment", "Infection", "Virus"),
      required = FALSE
    )
    config$group_column <- if (!is.null(detected_group)) {
      detected_group
    } else if (interactive_allowed) {
      pdt_prompt_column("Group column", columns)
    } else {
      stop("Supply --group-column for time-course analysis.", call. = FALSE)
    }
  }
  missing_design_columns <- setdiff(
    c(config$time_column, config$group_column), columns
  )
  if (length(missing_design_columns)) {
    stop(
      "Time-course design column(s) not found: ",
      paste(missing_design_columns, collapse = ", "),
      call. = FALSE
    )
  }

  time_values <- suppressWarnings(as.numeric(annotation[[config$time_column]]))
  if (any(!is.finite(time_values))) {
    stop("The selected time column must contain numeric values.", call. = FALSE)
  }
  group_values <- unique(as.character(annotation[[config$group_column]]))
  group_values <- group_values[!is.na(group_values) & nzchar(group_values)]
  if (length(group_values) < 2L) {
    stop("Time-course analysis requires at least two groups.", call. = FALSE)
  }

  if (!pdt_is_set(config$reference_group)) {
    if (interactive_allowed) {
      config$reference_group <- pdt_prompt(
        paste0("Reference group (", paste(group_values, collapse = ", "), ")"),
        group_values[[1]], TRUE
      )
    } else {
      stop("Supply --reference-group for time-course analysis.", call. = FALSE)
    }
  }
  if (!pdt_is_set(config$comparison_group)) {
    comparison_default <- setdiff(group_values, config$reference_group)[[1]]
    if (interactive_allowed) {
      config$comparison_group <- pdt_prompt(
        paste0("Comparison group (", paste(group_values, collapse = ", "), ")"),
        comparison_default, TRUE
      )
    } else {
      stop("Supply --comparison-group for time-course analysis.", call. = FALSE)
    }
  }
  selected_groups <- c(config$reference_group, config$comparison_group)
  if (anyDuplicated(selected_groups) || !all(selected_groups %in% group_values)) {
    stop(
      "Reference and comparison groups must be different values from: ",
      paste(group_values, collapse = ", "),
      call. = FALSE
    )
  }

  config$time_unit <- pdt_numeric(config$time_unit, "time_unit", minimum = .Machine$double.eps)
  config$min_replicates_per_cell <- pdt_numeric(
    config$min_replicates_per_cell, "min_replicates_per_cell",
    integer = TRUE, minimum = 1
  )
  config$polynomial_degree <- pdt_numeric(
    config$polynomial_degree, "polynomial_degree", integer = TRUE, minimum = 1
  )
  config$spline_df <- pdt_numeric(
    config$spline_df, "spline_df", integer = TRUE, minimum = 1
  )
  config$model_fdr <- pdt_numeric(config$model_fdr, "model_fdr", minimum = 0, maximum = 1)
  config$limma_interaction_fdr <- pdt_numeric(
    config$limma_interaction_fdr,
    "limma_interaction_fdr",
    minimum = 0,
    maximum = 1
  )
  config$coefficient_alpha <- pdt_numeric(
    config$coefficient_alpha, "coefficient_alpha", minimum = 0, maximum = 1
  )
  config$min_r_squared <- pdt_numeric(
    config$min_r_squared, "min_r_squared", minimum = 0, maximum = 1
  )
  config$min_clusters <- pdt_numeric(
    config$min_clusters, "min_clusters", integer = TRUE, minimum = 2
  )
  config$max_clusters <- pdt_numeric(
    config$max_clusters, "max_clusters", integer = TRUE,
    minimum = config$min_clusters
  )
  config$cluster_diagnostic_repeats <- pdt_numeric(
    config$cluster_diagnostic_repeats, "cluster_diagnostic_repeats",
    integer = TRUE, minimum = 1
  )
  config$core_membership <- pdt_numeric(
    config$core_membership, "core_membership", minimum = 0, maximum = 1
  )

  if (pdt_is_set(config$extra_qmd)) {
    config$extra_qmd <- vapply(
      as.character(config$extra_qmd),
      pdt_resolve_path,
      character(1),
      base_dir = project_root,
      must_work = TRUE
    )
  }
  if (pdt_is_set(config$report_template)) {
    config$report_template <- pdt_resolve_path(
      config$report_template, project_root, TRUE
    )
  }
  config
}

pdt_write_config <- function(config, file) {
  dir.create(dirname(file), recursive = TRUE, showWarnings = FALSE)
  # yaml writes R logical values as yes/no by default (YAML 1.1). Quarto uses
  # YAML 1.2, where those values are strings. true/false works in both parsers.
  yaml::write_yaml(
    config,
    file,
    handlers = list(logical = yaml::verbatim_logical)
  )
  normalizePath(file, winslash = "/", mustWork = TRUE)
}
