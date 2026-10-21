pdt_stage_quarto_report <- function(report_file, repo_root, prefix) {
  report_file <- normalizePath(
    report_file, winslash = "/", mustWork = TRUE
  )
  repo_root <- normalizePath(
    repo_root, winslash = "/", mustWork = TRUE
  )

  staging_dir <- tempfile(pattern = prefix)
  if (!dir.create(staging_dir, recursive = TRUE, showWarnings = FALSE)) {
    stop(
      "Could not create the temporary Quarto staging directory: ",
      staging_dir,
      call. = FALSE
    )
  }

  staged_report <- file.path(staging_dir, basename(report_file))
  if (!file.copy(
    report_file,
    staged_report,
    overwrite = TRUE,
    copy.mode = FALSE
  )) {
    unlink(staging_dir, recursive = TRUE, force = TRUE)
    stop(
      "Could not copy the Quarto report into its writable staging directory.",
      call. = FALSE
    )
  }
  Sys.chmod(staged_report, mode = "0600")

  # Reports load shared R helpers and styles relative to their own location.
  # Copy these small directories so Quarto never needs to write beside the
  # workflow checkout, which is mounted read-only by the HPC launcher.
  for (resource in c("R", "assets")) {
    source_path <- file.path(repo_root, resource)
    if (!dir.exists(source_path)) next
    if (!file.copy(source_path, staging_dir, recursive = TRUE)) {
      unlink(staging_dir, recursive = TRUE, force = TRUE)
      stop(
        "Could not stage the Quarto resource directory: ", source_path,
        call. = FALSE
      )
    }
  }

  list(directory = staging_dir, report = staged_report)
}
