#!/usr/bin/env Rscript

script_argument <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
script_file <- sub("^--file=", "", script_argument[[1]])
repo_root <- normalizePath(
  file.path(dirname(script_file), ".."), winslash = "/", mustWork = TRUE
)

required_packages <- c("data.table", "readxl", "yaml")
missing_packages <- required_packages[
  !vapply(required_packages, requireNamespace, logical(1), quietly = TRUE)
]
if (length(missing_packages)) {
  stop("Missing test package(s): ", paste(missing_packages, collapse = ", "))
}

source(file.path(repo_root, "R", "input-functions.R"))
source(file.path(repo_root, "R", "wrapper-functions.R"))

stopifnot(identical(pdt_main_defaults()$gsea_pvalue_cutoff, 0.05))
stopifnot(identical(pdt_main_defaults()$maximum_allowed_fold_change, 100))

parsed <- pdt_parse_cli(c(
  "run",
  "--psm", "psm.csv",
  "--annotation=annotation.csv",
  "--outputs", "html,excel",
  "--extra-qmd", "first.qmd",
  "--extra-qmd", "second.qmd",
  "--no-gsea",
  "--remove-few-measurements",
  "--de-pvalue-cutoff", "0.5",
  "--de-log2fc-cutoff", "0.25",
  "--maximum-allowed-fold-change", "1000",
  "--gsea-pvalue-cutoff", "0.5",
  "--spline-df", "4",
  "--limma-interaction-fdr", "0.1",
  "--with-dependencies"
))
stopifnot(
  identical(parsed$command, "run"),
  identical(parsed$options$psm, "psm.csv"),
  identical(parsed$options$annotation, "annotation.csv"),
  identical(parsed$options$extra_qmd, c("first.qmd", "second.qmd")),
  identical(parsed$options$run_gsea, FALSE),
  identical(parsed$options$remove_few_measurements_value, TRUE),
  identical(parsed$options$de_pvalue_cutoff, "0.5"),
  identical(parsed$options$de_log2fc_cutoff, "0.25"),
  identical(parsed$options$maximum_allowed_fold_change, "1000"),
  identical(parsed$options$gsea_pvalue_cutoff, "0.5"),
  identical(parsed$options$spline_df, "4"),
  identical(parsed$options$limma_interaction_fdr, "0.1"),
  identical(parsed$options$with_dependencies, TRUE)
)

stopifnot(
  identical(
    pdt_resolve_outputs(list(outputs = "all"), interactive_allowed = FALSE),
    c("html", "excel", "timecourse")
  ),
  identical(
    pdt_resolve_outputs(
      list(outputs = "timecourse,excel"), interactive_allowed = FALSE
    ),
    c("timecourse", "excel")
  )
)

dependency_file <- tempfile("pdtomsstats-analysis-", fileext = ".rds")
reuse_error <- tryCatch(
  pdt_plan_main_analysis(c("timecourse"), dependency_file),
  error = identity
)
stopifnot(
  inherits(reuse_error, "error"),
  grepl("--with-dependencies", conditionMessage(reuse_error), fixed = TRUE)
)
dependency_plan <- pdt_plan_main_analysis(
  c("timecourse"), dependency_file, with_dependencies = TRUE
)
stopifnot(isTRUE(dependency_plan$run), identical(dependency_plan$action, "run"))
stopifnot(file.create(dependency_file))
reuse_plan <- pdt_plan_main_analysis(c("excel", "timecourse"), dependency_file)
stopifnot(!reuse_plan$run, identical(reuse_plan$action, "reuse"))
html_plan <- pdt_plan_main_analysis(c("html", "excel"), dependency_file)
stopifnot(isTRUE(html_plan$run), identical(html_plan$action, "run"))
unlink(dependency_file)

alternative_psm <- data.frame(
  Run = "run-1",
  `Modified Sequence` = "PEPTIDE",
  `Precursor Charge` = 2,
  Accession = "P00001",
  Intensity = 100,
  check.names = FALSE
)
normalized_psm <- normalize_psm_columns(alternative_psm, list(
  psm_file_id_column = "Run",
  psm_sequence_column = "Modified Sequence",
  psm_charge_column = "Precursor Charge",
  psm_protein_column = "Accession",
  psm_intensity_column = "Intensity"
))
stopifnot(all(c(
  "File ID", "Annotated Sequence", "Charge",
  "Master Protein Accessions", "Quan Value"
) %in% names(normalized_psm)))

alternative_annotation <- data.frame(
  Run = c("run-1", "run-2"),
  TimePoint = c(0, 24),
  Infection = c("Control", "Treatment"),
  check.names = FALSE
)
annotation_config <- list(
  annotation_file_id_column = "Run",
  file_name_from_file_id = TRUE,
  bioreplicate_from_file_id = TRUE,
  condition_columns = c("TimePoint", "Infection")
)
normalized_annotation <- normalize_annotation_columns(
  alternative_annotation, annotation_config
)
stopifnot(
  identical(normalized_annotation[["File Name"]], c("run-1", "run-2")),
  identical(normalized_annotation[["BioReplicate"]], c("run-1", "run-2"))
)

test_dir <- tempfile("pdtomsstats-wrapper-")
dir.create(test_dir, recursive = TRUE)
on.exit(unlink(test_dir, recursive = TRUE, force = TRUE), add = TRUE)

psm_file <- file.path(test_dir, "psm.csv")
annotation_file <- file.path(test_dir, "annotation.csv")
data.table::fwrite(alternative_psm, psm_file)
data.table::fwrite(alternative_annotation, annotation_file)

options <- list(
  psm = psm_file,
  annotation = annotation_file,
  outputs = "html,timecourse",
  request = "wrapper-test",
  output_dir = file.path(test_dir, "results"),
  figures_dir = file.path(test_dir, "figures"),
  condition_columns = "TimePoint,Infection",
  condition_template = "{TimePoint}h_{Infection}",
  run_gsea = FALSE,
  time_column = "TimePoint",
  group_column = "Infection",
  reference_group = "Control",
  comparison_group = "Treatment",
  de_pvalue_cutoff = "0.5",
  de_log2fc_cutoff = "0.25",
  maximum_allowed_fold_change = "1000",
  gsea_pvalue_cutoff = "0.5"
)
provided <- names(options)
prepared <- pdt_prepare_main_config(
  options, provided, test_dir, interactive_allowed = FALSE
)
stopifnot(
  identical(prepared$config$psm_file_id_column, "Run"),
  identical(prepared$config$psm_sequence_column, "Modified Sequence"),
  identical(prepared$config$psm_charge_column, "Precursor Charge"),
  identical(prepared$config$psm_protein_column, "Accession"),
  identical(prepared$config$psm_intensity_column, "Intensity"),
  identical(prepared$config$differential_pvalue_cutoff, 0.5),
  identical(prepared$config$differential_log2fc_cutoff, 0.25),
  identical(prepared$config$maximum_allowed_fold_change, 1000),
  identical(prepared$config$gsea_pvalue_cutoff, 0.5),
  isTRUE(prepared$config$file_name_from_file_id),
  isTRUE(prepared$config$bioreplicate_from_file_id),
  identical(
    prepared$conditions,
    c("0h_Control", "24h_Treatment")
  )
)

timecourse <- pdt_prepare_timecourse_config(
  prepared$config,
  prepared$annotation,
  options,
  provided,
  test_dir,
  interactive_allowed = FALSE
)
stopifnot(
  identical(timecourse$time_column, "TimePoint"),
  identical(timecourse$group_column, "Infection"),
  identical(timecourse$reference_group, "Control"),
  identical(timecourse$comparison_group, "Treatment"),
  identical(timecourse$polynomial_degree, 3L),
  identical(timecourse$spline_df, 3L),
  identical(timecourse$model_fdr, 0.05),
  identical(timecourse$limma_interaction_fdr, 0.05)
)

custom_timecourse_options <- options
custom_timecourse_options$spline_df <- "4"
custom_timecourse_options$limma_interaction_fdr <- "0.1"
custom_timecourse <- pdt_prepare_timecourse_config(
  prepared$config,
  prepared$annotation,
  custom_timecourse_options,
  names(custom_timecourse_options),
  test_dir,
  interactive_allowed = FALSE
)
stopifnot(
  identical(custom_timecourse$spline_df, 4L),
  identical(custom_timecourse$limma_interaction_fdr, 0.1)
)

config_file <- pdt_write_config(
  prepared$config, file.path(test_dir, "resolved.yml")
)
round_trip <- yaml::read_yaml(config_file)
stopifnot(
  identical(round_trip$request, "wrapper-test"),
  identical(round_trip$psm_file_id_column, "Run")
)
written_text <- readLines(config_file, warn = FALSE)
stopifnot(any(grepl("^remove_shared_peptides: true$", written_text)))
stopifnot(any(grepl("^run_gsea: false$", written_text)))
stopifnot(any(grepl("^differential_pvalue_cutoff: 0.5$", written_text)))
stopifnot(any(grepl("^differential_log2fc_cutoff: 0.25$", written_text)))
stopifnot(identical(as.numeric(round_trip$maximum_allowed_fold_change), 1000))
stopifnot(any(grepl("^gsea_pvalue_cutoff: 0.5$", written_text)))

default_options <- options
default_options$de_pvalue_cutoff <- NULL
default_options$de_log2fc_cutoff <- NULL
default_options$maximum_allowed_fold_change <- NULL
default_provided <- setdiff(
  names(default_options),
  c("de_pvalue_cutoff", "de_log2fc_cutoff", "maximum_allowed_fold_change")
)
default_prepared <- pdt_prepare_main_config(
  default_options,
  default_provided,
  test_dir,
  interactive_allowed = FALSE
)
stopifnot(
  identical(default_prepared$config$maximum_allowed_fold_change, 100),
  identical(
    default_prepared$config$differential_pvalue_cutoff,
    default_prepared$config$volcano_p_cutoff
  ),
  identical(
    default_prepared$config$differential_log2fc_cutoff,
    default_prepared$config$volcano_fc_cutoff
  )
)

invalid_options <- options
invalid_options$de_pvalue_cutoff <- "1.1"
invalid_error <- tryCatch({
  pdt_prepare_main_config(
    invalid_options,
    names(invalid_options),
    test_dir,
    interactive_allowed = FALSE
  )
  NULL
}, error = identity)
stopifnot(
  inherits(invalid_error, "error"),
  grepl("differential_pvalue_cutoff", conditionMessage(invalid_error), fixed = TRUE)
)

invalid_gsea_options <- options
invalid_gsea_options$gsea_pvalue_cutoff <- "-0.1"
invalid_gsea_error <- tryCatch({
  pdt_prepare_main_config(
    invalid_gsea_options,
    names(invalid_gsea_options),
    test_dir,
    interactive_allowed = FALSE
  )
  NULL
}, error = identity)
stopifnot(
  inherits(invalid_gsea_error, "error"),
  grepl("gsea_pvalue_cutoff", conditionMessage(invalid_gsea_error), fixed = TRUE)
)

for (invalid_limit in c("0", "-1", "Inf", "NaN", "not-a-number")) {
  invalid_limit_options <- options
  invalid_limit_options$maximum_allowed_fold_change <- invalid_limit
  limit_error <- tryCatch(
    pdt_prepare_main_config(
      invalid_limit_options, names(invalid_limit_options), test_dir,
      interactive_allowed = FALSE
    ),
    error = identity
  )
  stopifnot(
    inherits(limit_error, "error"),
    grepl("maximum_allowed_fold_change", conditionMessage(limit_error), fixed = TRUE)
  )
}

cat("Wrapper parsing, mapping, and configuration: PASS\n")
