# =============================================================================
# STANDARD CLEANING PIPELINE (workplan Section III, steps 4-7, tract level)
# -----------------------------------------------------------------------------
# Every source goes through the same steps once its raw data are in "long"
# shape (one row per tract and year). The source script handles anything
# unique to that source; clean_source() does the rest:
#
#   4a.i   standardize the tract ID to 11 characters; name it by vintage
#          (GEOID20 / GEOID10) so 2010 and 2020 tracts can't be mixed up
#   4a.vi  keep the study county
#   --     keep STUDY_YEARS
#   4d/6   keep ID, year, then the measures in measures.csv order, renamed
#   8d     check_panel(): 1 row = 1 tract-year, nrow = tracts x years
#   7      save CSV + .RData to data/supplemental_clean/
# =============================================================================

#' @param df           Long data: one row per tract-year, measure columns named as in
#'                     measures.csv `raw_var`.
#' @param source_id    Must match config/sources.csv.
#' @param id_col_raw   Name of the tract ID column in `df`.
#' @param year_col_raw Name of the year column in `df`.
#' @param id_format    How the raw tract IDs look; see standardize_tract().
#' @param save         Set FALSE to inspect without writing files.
clean_source <- function(df, source_id, id_col_raw, year_col_raw = "year",
                         id_format = "geoid", save = TRUE) {
  src  <- get_source(source_id)
  meas <- get_measures(source_id)
  message("\n== Cleaning ", source_id, " ==")

  missing_vars <- setdiff(c(id_col_raw, year_col_raw, meas$raw_var), names(df))
  if (length(missing_vars)) {
    stop("Columns listed for ", source_id, " are not in the data: ",
         paste(missing_vars, collapse = ", "),
         "\nFix the source script's prep step or raw_var in config/measures.csv.", call. = FALSE)
  }

  id_col <- id_col_name(src$geo_vintage)
  if (id_col != id_col_name(TARGET_TRACT_VINTAGE)) {
    message("NOTE: ", source_id, " uses ", src$geo_vintage, " tracts. It will be saved as ", id_col,
            " but left out of supp_all_SDoW until harmonized to ", TARGET_TRACT_VINTAGE, " tracts.")
  }

  out <- df |>
    dplyr::transmute(
      !!id_col := standardize_tract(.data[[id_col_raw]], format = id_format),
      year     = as.integer(.data[[year_col_raw]]),
      dplyr::across(dplyr::all_of(meas$raw_var))
    ) |>
    dplyr::rename(dplyr::all_of(stats::setNames(meas$raw_var, meas$clean_var))) |>
    filter_county(id_col) |>
    dplyr::filter(year %in% STUDY_YEARS) |>
    dplyr::select(dplyr::all_of(c(id_col, "year", meas$clean_var))) |>
    dplyr::arrange(.data[[id_col]], year)

  check_panel(out, id_col)
  if (save) save_clean(out, src$clean_file)
  invisible(out)
}
