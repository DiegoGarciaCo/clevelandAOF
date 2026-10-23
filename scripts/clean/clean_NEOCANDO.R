# =============================================================================
# CLEAN: NEOCANDO Neighborhood Data System
# -----------------------------------------------------------------------------
# Source ID : NEOCANDO
# Raw input : data/supplemental_raw/NEOCANDO/<export>.csv   (not downloaded yet)
# Output    : data/supplemental_clean/supp_NEOCANDO.csv / .RData
# -----------------------------------------------------------------------------
# STATUS: skeleton. Finish once the export is downloaded:
#   1. Put the CSV export(s) in data/supplemental_raw/NEOCANDO/ and the
#      technical documents in its documentation/ subfolder.
#   2. Fill in raw_file and geo_vintage in config/sources.csv.
#   3. Fill in the TODO definitions in config/measures.csv
#      (numerators/denominators, how "adequate" prenatal care is defined).
#   4. Adjust section 3 below to the export's actual layout, then set status
#      to "ready" in sources.csv.
# =============================================================================

source(here::here("scripts", "00_setup.R"))
SOURCE_ID <- "NEOCANDO"

# ---- 1. Import ---------------------------------------------------------------
# If you exported one file per measure, read them all and join on the tract ID:
#   files <- list.files(raw_dir(SOURCE_ID), pattern = "\\.csv$", full.names = TRUE)
raw <- readr::read_csv(raw_file(SOURCE_ID))

# ---- 2. Explore --------------------------------------------------------------
if (interactive()) {
  glimpse(raw)
  names(raw)
}

# ---- 3. Source-specific preparation -----------------------------------------
# NEOCANDO exports are usually WIDE: one column per variable-year. Reshape to
# one row per tract-year with columns foreclosure_rate, vacancy_rate,
# prenatal_adequate_pct (the raw_var names in measures.csv).
# Example only -- adjust the patterns to the real column names:
#
# prepped <- raw |>
#   pivot_longer(-tract_col, names_to = "variable", values_to = "value") |>
#   mutate(
#     year    = as.integer(str_extract(variable, "\\d{4}")),
#     measure = case_when(
#       str_detect(variable, regex("foreclos", ignore_case = TRUE)) ~ "foreclosure_rate",
#       str_detect(variable, regex("vacan",    ignore_case = TRUE)) ~ "vacancy_rate",
#       str_detect(variable, regex("prenatal", ignore_case = TRUE)) ~ "prenatal_adequate_pct"
#     )
#   ) |>
#   select(tract_col, year, measure, value) |>
#   pivot_wider(names_from = measure, values_from = value)
prepped <- raw

# ---- 4. Standard pipeline ----------------------------------------------------
clean_source(
  prepped,
  source_id    = SOURCE_ID,
  id_col_raw   = "tract_col",       # TODO: real column name
  year_col_raw = "year",
  id_format    = "tract_number"     # TODO: check -- NEOCANDO may use e.g. "1011.01"
)
