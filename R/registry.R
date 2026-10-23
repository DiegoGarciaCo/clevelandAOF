# =============================================================================
# REGISTRY: read config/sources.csv and config/measures.csv
# -----------------------------------------------------------------------------
# The two CSVs are the single source of truth for what each data source is and
# which measures we keep. Scripts look things up here instead of hard-coding
# file names or variable names.
# =============================================================================

read_sources <- function() {
  readr::read_csv(file.path(PATHS$config, "sources.csv"),
                  col_types = readr::cols(.default = "c"), na = "")
}

read_measures <- function() {
  readr::read_csv(file.path(PATHS$config, "measures.csv"),
                  col_types = readr::cols(.default = "c"), na = "")
}

#' One source's row from sources.csv, as a list.
get_source <- function(source_id) {
  src <- dplyr::filter(read_sources(), .data$source_id == !!source_id)
  if (nrow(src) != 1) {
    stop("source_id '", source_id, "' must appear exactly once in config/sources.csv ",
         "(found ", nrow(src), ").", call. = FALSE)
  }
  as.list(src)
}

#' One source's measures from measures.csv.
get_measures <- function(source_id) {
  m <- dplyr::filter(read_measures(), .data$source_id == !!source_id)
  if (nrow(m) == 0) {
    stop("No measures listed for '", source_id, "' in config/measures.csv.", call. = FALSE)
  }
  dup <- m$clean_var[duplicated(m$clean_var)]
  if (length(dup)) stop("Duplicate clean_var in measures.csv: ", paste(dup, collapse = ", "), call. = FALSE)
  m
}

#' Name of the tract ID column for a vintage, e.g. "GEOID20" or "GEOID10".
#' Using the vintage in the name means 2010 and 2020 tracts can never be merged by accident.
id_col_name <- function(vintage) {
  vintage <- as.integer(vintage)
  if (is.na(vintage)) stop("geo_vintage is not set for this source in sources.csv.", call. = FALSE)
  paste0("GEOID", substr(vintage, 3, 4))
}
