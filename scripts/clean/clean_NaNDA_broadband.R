# =============================================================================
# CLEAN: NaNDA Broadband Internet Availability, Speed, and Adoption (ICPSR 38567, DS1)
# -----------------------------------------------------------------------------
# Source ID : NaNDA_broadband
# Raw input : data/supplemental_raw/NaNDA_broadband/38567-0001-Data.rda
# Output    : data/supplemental_clean/supp_NaNDA_broadband.csv / .RData
# -----------------------------------------------------------------------------
# Notes from the documentation (details in config/measures.csv):
#   - Tract IDs are the 2010 vintage (TRACT_FIPS10). Output is keyed GEOID10
#     and stays out of the merged file until it is harmonized to 2020 tracts.
#   - Years 2014-2020; adoption is real only for 2015-2018.
#   - Adoption (RFHSC_PER_1000_HHS_10_1) is a 6-level category, stored in the
#     .rda as a factor with labels like "(4) 600 < x <= 800".
# =============================================================================

source(here::here("scripts", "00_setup.R"))
SOURCE_ID <- "NaNDA_broadband"

# ---- 1. Import ---------------------------------------------------------------
raw <- load_rda(raw_file(SOURCE_ID))

# ---- 2. Explore --------------------------------------------------------------
if (interactive()) {
  glimpse(raw)
  summary(raw)
  levels(raw$RFHSC_PER_1000_HHS_10_1)
}

# ---- 3. Source-specific preparation -----------------------------------------
# Factor labels "(k) ..." -> integer code k (0-5). NA stays NA.
category_code <- function(x) as.integer(sub("^\\((\\d+)\\).*$", "\\1", as.character(x)))

prepped <- raw |>
  mutate(
    TRACT_FIPS10            = as.character(TRACT_FIPS10),
    RFHSC_PER_1000_HHS_10_1 = category_code(RFHSC_PER_1000_HHS_10_1)
  )

# ---- 4. Standard pipeline ----------------------------------------------------
clean_source(
  prepped,
  source_id    = SOURCE_ID,
  id_col_raw   = "TRACT_FIPS10",
  year_col_raw = "YEAR",
  id_format    = "geoid"
)
