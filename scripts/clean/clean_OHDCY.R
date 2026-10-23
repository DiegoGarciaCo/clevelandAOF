# =============================================================================
# CLEAN: Ohio Department of Children and Youth -- Early Care and Education Programs
# -----------------------------------------------------------------------------
# Source ID : OHDCY
# Raw input : data/supplemental_raw/OHDCY/OhioEarlyCareAndEducationPrograms.csv
# Output    : data/supplemental_clean/supp_OHDCY.csv / .RData
# -----------------------------------------------------------------------------
# STATUS: BLOCKED (see docs/decisions_log.md).
#   The current export lists program name, address, type, SUTQ rating and
#   license dates, but has NO price and NO capacity fields, and it is a
#   snapshot of currently licensed programs (closed programs are not in it).
#
# This script shows the address-level workflow (workplan step 4b at tract
# level), which is reusable for any address-level source:
#   addresses -> geocode_to_tract() -> aggregate_addresses() -> clean_source()
# =============================================================================

source(here::here("scripts", "00_setup.R"))
SOURCE_ID <- "OHDCY"

# ---- 1. Import ---------------------------------------------------------------
raw <- readr::read_csv(raw_file(SOURCE_ID), col_types = cols(.default = "c"))

# ---- 2. Explore --------------------------------------------------------------
if (interactive()) {
  glimpse(raw)
  count(raw, `PROGRAM TYPE`)
}

# ---- 3. Source-specific preparation -----------------------------------------
# 4b.i.1: street, city, state, ZIP in separate columns (row_id added when geocoding)
programs <- raw |>
  filter(str_to_upper(COUNTY) == str_to_upper(COUNTY_NAME)) |>
  transmute(program_id = `PROGRAM NUMBER`, program_type = `PROGRAM TYPE`,
            street = `STREET ADDRESS`, city = CITY, state = STATE,
            zip = str_pad(`ZIP CODE`, 5, pad = "0"))

# 4b.i.2-3: geocode and assign 2020 tracts (needs internet). Cached so it runs once.
geo_cache <- file.path(PATHS$reference, "OHDCY_programs_geocoded.csv")
if (!file.exists(geo_cache)) {
  programs_geo <- geocode_to_tract(programs, "street", "city", "state", "zip")
  write_csv(programs_geo, geo_cache)
}
programs_geo <- read_csv(geo_cache, col_types = cols(GEOID20 = "c", .default = col_guess()))

# TODO once price/capacity data exist: join them to programs_geo by program_id
# (one row per program per year, columns named childcare_price and
# childcare_capacity), then:
#   prepped <- aggregate_addresses(programs_year, SOURCE_ID)   # sum capacity, median price
#   prepped <- tidyr::complete(prepped, GEOID20, year)          # every tract has every year
stop("OHDCY: no price or capacity fields yet -- see docs/decisions_log.md.")

# ---- 4. Standard pipeline ----------------------------------------------------
clean_source(prepped, SOURCE_ID, id_col_raw = "GEOID20", year_col_raw = "year", id_format = "geoid")
