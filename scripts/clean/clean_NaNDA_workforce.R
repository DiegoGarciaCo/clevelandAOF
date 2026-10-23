# =============================================================================
# CLEAN: NaNDA Training and Vocation Schools by Census Tract (ICPSR 302343)
# -----------------------------------------------------------------------------
# Source ID : NaNDA_workforce
# Raw input : data/supplemental_raw/NaNDA_workforce/nanda_trainvoc_Tract20_1990-2022_01P.dta
# Output    : data/supplemental_clean/supp_NaNDA_workforce.csv / .RData
# -----------------------------------------------------------------------------
# Notes from the documentation (v1.3, details in config/measures.csv):
#   - Tract20 file uses 2020 tracts (tract_fips20); years 1990-2022.
#   - den_* = establishments per 1,000 residents; missing when population = 0.
#   - "Professional development schools" in the workplan = NaNDA's
#     "Personal Development Schools" (den_develscho).
# Written against the documented variable names; first run not yet done
# because the .dta has not been downloaded.
# =============================================================================

source(here::here("scripts", "00_setup.R"))
SOURCE_ID <- "NaNDA_workforce"

# ---- 1. Import ---------------------------------------------------------------
raw <- haven::read_dta(raw_file(SOURCE_ID))

# ---- 2. Explore --------------------------------------------------------------
if (interactive()) {
  glimpse(raw)
  summary(select(raw, starts_with("den_")))
}

# ---- 3. Source-specific preparation -----------------------------------------
# Already long (one row per tract-year). Drop Stata labels so columns are plain numeric.
prepped <- haven::zap_labels(raw)

# ---- 4. Standard pipeline ----------------------------------------------------
clean_source(
  prepped,
  source_id    = SOURCE_ID,
  id_col_raw   = "tract_fips20",
  year_col_raw = "year",
  id_format    = "geoid"
)
