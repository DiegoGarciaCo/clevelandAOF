# =============================================================================
# PROJECT SETTINGS
# -----------------------------------------------------------------------------
# Every project-wide choice lives here. If you find yourself typing one of
# these values inside a script, use the setting instead.
# =============================================================================

# ---- Study scope -------------------------------------------------------------
STUDY_YEARS  <- 2015:2025   # years kept in every clean dataset
STATE_FIPS   <- "39"        # Ohio
COUNTY_FIPS  <- "035"       # Cuyahoga
COUNTY_NAME  <- "Cuyahoga"

# ---- Geography ---------------------------------------------------------------
# All clean data are kept at census-tract level (workplan, Section I).
# The merged file uses this tract vintage. Clean files on another vintage are
# saved, but left out of the merge until harmonized (workplan step 4a.ii).
TARGET_TRACT_VINTAGE <- 2020

# ---- Folder locations --------------------------------------------------------
# here::here() always points at the project root (the folder holding the
# .Rproj file), so these paths work on any computer.
PATHS <- list(
  config    = here::here("config"),
  raw       = here::here("data", "supplemental_raw"),
  clean     = here::here("data", "supplemental_clean"),
  reference = here::here("data", "reference"),
  outputs   = here::here("outputs"),
  scripts   = here::here("scripts")
)

CODEBOOK_FILE <- file.path(PATHS$outputs, "LQ1_Supplemental_Data_Codebook.xlsx")
REPORT_DIR    <- PATHS$clean   # workplan IV.7: knitted report goes in supplemental_clean
