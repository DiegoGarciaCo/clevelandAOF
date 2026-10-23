# =============================================================================
# CHECKS: confirm a clean dataset has the agreed structure before it's saved
# =============================================================================

#' Workplan "Confirm the structure" + "1 row = 1 tract-year" checks.
#' Stops with a clear message if:
#'   - any tract-year appears more than once
#'   - nrow() != number of tracts x number of years (every tract has every year;
#'     years with no data must be present as NA rows, not missing rows)
#'   - tract IDs are not 11-character strings
#'   - any year is outside STUDY_YEARS
#'   - any measure column is not numeric
#' Then reports coverage against the county's full tract list (when available)
#' and prints the share missing per measure per year.
check_panel <- function(df, id_col, years = STUDY_YEARS) {
  problems <- character()
  if (!all(c(id_col, "year") %in% names(df))) {
    stop("Data must contain '", id_col, "' and 'year' columns.", call. = FALSE)
  }
  measure_cols <- setdiff(names(df), c(id_col, "year"))
  n_units <- dplyr::n_distinct(df[[id_col]])
  n_years <- dplyr::n_distinct(df$year)

  n_dup <- sum(duplicated(df[c(id_col, "year")]))
  if (n_dup) problems <- c(problems, paste(n_dup, "duplicate", id_col, "x year rows"))

  if (nrow(df) != n_units * n_years) {
    problems <- c(problems, sprintf(
      "nrow() is %d but should be %d tracts x %d years = %d. Some tract-years are missing rows; use tidyr::complete(%s, year) in the source script's prep step.",
      nrow(df), n_units, n_years, n_units * n_years, id_col))
  }
  if (anyNA(df[[id_col]]) || any(nchar(df[[id_col]]) != 11)) {
    problems <- c(problems, paste0(id_col, " values must be 11-character strings with no NAs"))
  }
  bad_years <- setdiff(unique(df$year), years)
  if (length(bad_years)) problems <- c(problems, paste("years outside STUDY_YEARS:", paste(bad_years, collapse = ", ")))

  non_num <- measure_cols[!vapply(df[measure_cols], is.numeric, logical(1))]
  if (length(non_num)) problems <- c(problems, paste("non-numeric measures:", paste(non_num, collapse = ", ")))

  if (length(problems)) stop("check_panel() failed:\n  - ", paste(problems, collapse = "\n  - "), call. = FALSE)

  message(sprintf("check_panel() passed: %d rows = %d tracts x %d years (%s)",
                  nrow(df), n_units, n_years, year_span(df$year)))
  report_tract_coverage(df[[id_col]], id_col)
  print(missing_by_year(df, measure_cols))
  invisible(df)
}

#' Compare tracts in the data with all tracts in the county (same vintage).
report_tract_coverage <- function(ids, id_col) {
  vintage <- paste0("20", sub("GEOID", "", id_col))
  all_ids <- county_tracts(vintage)
  if (is.null(all_ids)) return(invisible())
  absent <- setdiff(all_ids, ids)
  extra  <- setdiff(unique(ids), all_ids)
  message(sprintf("Tract coverage: %d of %d %s %s tracts present.",
                  length(intersect(all_ids, ids)), length(all_ids), COUNTY_NAME, vintage))
  if (length(absent)) message("  Not in data: ", paste(utils::head(absent, 10), collapse = ", "),
                              if (length(absent) > 10) " ...")
  if (length(extra)) warning(length(extra), " tract ID(s) not in the ", vintage,
                             " county tract list (vintage mismatch?): ",
                             paste(utils::head(extra, 5), collapse = ", "), call. = FALSE)
  invisible()
}

#' Percent missing for each measure in each year.
missing_by_year <- function(df, measure_cols) {
  df |>
    dplyr::group_by(year) |>
    dplyr::summarise(n_tracts = dplyr::n(),
                     dplyr::across(dplyr::all_of(measure_cols), ~ round(100 * mean(is.na(.x)), 1)),
                     .groups = "drop") |>
    as.data.frame()
}

#' Compact description of a set of years, e.g. "2015-2018, 2020".
year_span <- function(years) {
  y <- sort(unique(as.integer(years[!is.na(years)])))
  if (!length(y)) return("none")
  runs <- split(y, cumsum(c(1, diff(y) != 1)))
  paste(vapply(runs, function(r) if (length(r) == 1) as.character(r) else paste0(r[1], "-", r[length(r)]), ""),
        collapse = ", ")
}
