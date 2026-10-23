# =============================================================================
# GEOGRAPHY: tract IDs, county filtering, county tract list, geocoding
# =============================================================================

#' Standardize tract identifiers to 11-character GEOIDs
#' (state [39] + county [035] + 6-digit tract), workplan step 4a.i.
#'
#' `format` says what the raw values look like. It's required on purpose: the
#' same string can mean different things in different files, and naming the
#' format in each cleaning script documents what the raw data contained.
#'   "geoid"        full 11-digit GEOID; leading zero may have been lost -> "39035101100"
#'   "tract6"       6-digit tract code without state/county             -> "101100"
#'   "tract_number" tract number with optional decimal suffix           -> "1011", "1011.01"
#'                  (decimal removed and padded to 6 digits: "1011.01" -> "101101")
standardize_tract <- function(x, format = c("geoid", "tract6", "tract_number"),
                              state = STATE_FIPS, county = COUNTY_FIPS) {
  format <- match.arg(format)
  x <- trimws(as.character(x))
  x[x == ""] <- NA
  ok <- !is.na(x)
  out <- rep(NA_character_, length(x))

  out[ok] <- switch(format,
    geoid  = stringr::str_pad(x[ok], 11, pad = "0"),
    tract6 = paste0(state, county, stringr::str_pad(x[ok], 6, pad = "0")),
    tract_number = {
      parts  <- strsplit(x[ok], ".", fixed = TRUE)
      base   <- vapply(parts, `[`, "", 1)
      suffix <- vapply(parts, function(p) if (length(p) > 1) p[2] else "00", "")
      paste0(state, county,
             stringr::str_pad(base, 4, pad = "0"),
             stringr::str_pad(suffix, 2, side = "right", pad = "0"))
    }
  )

  bad <- ok & !grepl("^[0-9]{11}$", out)
  if (any(bad)) {
    stop("Could not build 11-digit GEOIDs for ", sum(bad), " value(s), e.g. '",
         x[bad][1], "'. Check the `format` argument.", call. = FALSE)
  }
  if (any(!ok)) warning(sum(!ok), " missing tract ID(s).", call. = FALSE)
  out
}

#' Keep only rows whose GEOID falls in the study county (workplan step 4a.vi).
filter_county <- function(df, id_col, state = STATE_FIPS, county = COUNTY_FIPS) {
  keep <- startsWith(df[[id_col]], paste0(state, county))
  message("County filter: kept ", sum(keep, na.rm = TRUE), " of ", nrow(df), " rows.")
  df[keep %in% TRUE, , drop = FALSE]
}

#' All census tracts in the study county for a vintage, via tigris (workplan step 4a.ii:
#' tr20 <- tracts(state = "OH", county = "Cuyahoga", year = 2020)).
#' Cached as a CSV of GEOIDs in data/reference/ so it downloads only once.
#' Returns NULL with a message if tigris is unavailable or offline.
county_tracts <- function(vintage = TARGET_TRACT_VINTAGE, refresh = FALSE) {
  cache <- file.path(PATHS$reference, sprintf("tracts%s_%s%s.csv", vintage, STATE_FIPS, COUNTY_FIPS))
  if (file.exists(cache) && !refresh) return(readr::read_csv(cache, col_types = "c")$GEOID)
  if (!requireNamespace("tigris", quietly = TRUE)) {
    message("tigris not installed -- skipping tract coverage check.")
    return(NULL)
  }
  tr <- tryCatch(
    tigris::tracts(state = STATE_FIPS, county = COUNTY_FIPS, year = as.integer(vintage),
                   cb = FALSE, progress_bar = FALSE),
    error = function(e) { message("Could not download tract list (", conditionMessage(e), ")."); NULL }
  )
  if (is.null(tr)) return(NULL)
  ids <- sort(tr$GEOID)
  dir.create(PATHS$reference, showWarnings = FALSE, recursive = TRUE)
  readr::write_csv(data.frame(GEOID = ids), cache)
  ids
}

# ---- Address-level sources (workplan step 4b, at tract level) ---------------

#' Geocode addresses with the free Census geocoder (tidygeocoder), then assign
#' each point to a 2020 census tract with a spatial join (workplan 4b.i).
#' Expects separate street / city / state / zip columns. Adds row_id, lat, long, GEOID20.
#' Warns if more than 5% of addresses are unmatched (check typos / PO boxes).
geocode_to_tract <- function(df, street, city, state, zip, max_unmatched = 0.05) {
  need_pkgs(c("tidygeocoder", "tigris", "sf"))
  df$row_id <- seq_len(nrow(df))          # unique ID so records can be traced

  geo <- tidygeocoder::geocode(
    df,
    street = !!rlang::sym(street), city = !!rlang::sym(city),
    state = !!rlang::sym(state), postalcode = !!rlang::sym(zip),
    method = "census"
  )
  share_missing <- mean(is.na(geo$lat))
  message(sprintf("Geocoding: %.1f%% of %d addresses unmatched.", 100 * share_missing, nrow(geo)))
  if (share_missing > max_unmatched) {
    warning("More than ", 100 * max_unmatched, "% unmatched -- check for typos and PO boxes.", call. = FALSE)
  }

  tracts <- tigris::tracts(state = STATE_FIPS, county = COUNTY_FIPS, year = 2020, progress_bar = FALSE) |>
    sf::st_transform(4326) |>
    dplyr::select(GEOID20 = GEOID)

  matched <- geo |>
    dplyr::filter(!is.na(lat)) |>
    sf::st_as_sf(coords = c("long", "lat"), crs = 4326, remove = FALSE) |>
    sf::st_join(tracts, join = sf::st_within) |>
    sf::st_drop_geometry()

  dplyr::bind_rows(matched, dplyr::filter(geo, is.na(lat)))
}

#' Summarise address-level records to tract-year (workplan 4b.ii, at tract level).
#' Uses agg_method from measures.csv for each measure:
#'   sum    -> counts: add values for all addresses in the tract
#'   median -> rates/prices: median across all addresses in the tract
aggregate_addresses <- function(df, source_id, id_col = "GEOID20", year_col = "year") {
  meas <- get_measures(source_id)
  bad <- setdiff(meas$agg_method, c("sum", "median"))
  if (length(bad) || anyNA(meas$agg_method)) {
    stop("agg_method for ", source_id, " must be 'sum' or 'median' in measures.csv.", call. = FALSE)
  }
  df |>
    dplyr::filter(!is.na(.data[[id_col]])) |>
    dplyr::group_by(dplyr::across(dplyr::all_of(c(id_col, year_col)))) |>
    dplyr::summarise(
      dplyr::across(
        dplyr::all_of(meas$raw_var),
        ~ if (all(is.na(.x))) NA_real_ else
            switch(meas$agg_method[meas$raw_var == dplyr::cur_column()],
                   sum    = sum(.x, na.rm = TRUE),
                   median = stats::median(.x, na.rm = TRUE))
      ),
      .groups = "drop"
    )
}

# ---- Helper ------------------------------------------------------------------

need_pkgs <- function(pkgs) {
  missing <- pkgs[!vapply(pkgs, requireNamespace, logical(1), quietly = TRUE)]
  if (length(missing)) {
    stop("Install required package(s) first: install.packages(c(",
         paste0('"', missing, '"', collapse = ", "), "))", call. = FALSE)
  }
}
