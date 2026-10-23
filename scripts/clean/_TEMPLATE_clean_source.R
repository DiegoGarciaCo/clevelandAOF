# =============================================================================
# CLEAN: <Source name>                         <-- replace
# -----------------------------------------------------------------------------
# Source ID : <source_id>     (must match config/sources.csv and the raw folder)
# Raw input : data/supplemental_raw/<source_id>/<raw_file>
# Output    : data/supplemental_clean/<clean_file>.csv / .RData
# Author    : <name>          Last run: <date>
# -----------------------------------------------------------------------------
# HOW TO ADD A NEW SOURCE
#   1. Save raw data + documentation in data/supplemental_raw/<source_id>/
#      (documentation goes in the documentation/ subfolder).
#   2. Add one row to config/sources.csv (status = "ready" when it runs).
#   3. Add one row per measure to config/measures.csv.
#   4. Copy this file to scripts/clean/clean_<source_id>.R and fill in
#      sections 1-3. Section 4 is the same for every source.
#   5. Run it, then run run_all.R to refresh the codebook and report.
# =============================================================================

source(here::here("scripts", "00_setup.R"))
SOURCE_ID <- "<source_id>"

# ---- 1. Import ---------------------------------------------------------------
# Pick the reader that matches the file type:
#   readr::read_csv(raw_file(SOURCE_ID))
#   haven::read_dta(raw_file(SOURCE_ID))
#   load_rda(raw_file(SOURCE_ID))
#   readxl::read_excel(raw_file(SOURCE_ID))
raw <- readr::read_csv(raw_file(SOURCE_ID))

# ---- 2. Explore (run interactively; record findings in measures.csv notes) ---
if (interactive()) {
  glimpse(raw)
  summary(raw)
}

# ---- 3. Source-specific preparation -----------------------------------------
# Goal: LONG data, one row per tract and year, with:
#   - a tract ID column and a year column (any names; you pass them below)
#   - one column per measure, named exactly as `raw_var` in measures.csv
# Typical steps: pivot wide year columns to long, fix types, recode
# categories, convert missing-value codes (e.g. -99) to NA.
# Every tract must have a row for every year: add tidyr::complete(<id>, year)
# if some tract-years are absent (check_panel() will tell you).
# Address-level data: see clean_OHDCY.R (geocode_to_tract() + aggregate_addresses()).
prepped <- raw

# ---- 4. Standard pipeline (same for every source) ---------------------------
clean_source(
  prepped,
  source_id    = SOURCE_ID,
  id_col_raw   = "<tract id column>",
  year_col_raw = "<year column>",
  id_format    = "geoid"          # or "tract6" / "tract_number" -- see R/geo.R
)
