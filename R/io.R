# =============================================================================
# INPUT / OUTPUT: finding raw files, saving and loading clean files
# =============================================================================

#' Folder holding a source's raw data: data/supplemental_raw/<source_id>/
raw_dir <- function(source_id) file.path(PATHS$raw, source_id)

#' Full path to a source's raw data file (name taken from sources.csv).
raw_file <- function(source_id, file = NULL) {
  if (is.null(file)) file <- get_source(source_id)$raw_file
  path <- file.path(raw_dir(source_id), file)
  if (!file.exists(path)) {
    stop("Raw file not found:\n  ", path,
         "\nDownload it (URL in config/sources.csv) and save it there.", call. = FALSE)
  }
  path
}

#' Load the single object stored in an .rda/.RData file and return it.
load_rda <- function(path) {
  env <- new.env()
  obj <- load(path, envir = env)
  if (length(obj) != 1) stop(path, " contains ", length(obj), " objects; expected 1.", call. = FALSE)
  env[[obj]]
}

#' Save a clean dataset as CSV + .RData in data/supplemental_clean/.
#' The object inside the .RData has the same name as the file (e.g. supp_NaNDA_broadband),
#' so load("supp_NaNDA_broadband.RData") recreates exactly that object.
save_clean <- function(df, name, dir = PATHS$clean) {
  dir.create(dir, showWarnings = FALSE, recursive = TRUE)
  csv  <- file.path(dir, paste0(name, ".csv"))
  rdat <- file.path(dir, paste0(name, ".RData"))
  readr::write_csv(df, csv, na = "")
  env <- new.env()
  assign(name, df, envir = env)
  save(list = name, envir = env, file = rdat)
  message("Saved ", nrow(df), " rows to:\n  ", csv, "\n  ", rdat)
  invisible(c(csv, rdat))
}

#' Load every clean source file (supp_*.RData, excluding the merged file) as a named list.
load_clean_all <- function(dir = PATHS$clean) {
  files <- list.files(dir, pattern = "^supp_.*\\.RData$", full.names = TRUE)
  files <- files[!grepl("^supp_all_", basename(files))]
  out <- lapply(files, load_rda)
  names(out) <- sub("\\.RData$", "", basename(files))
  out
}
