# Decisions and open questions

Record every judgment call here with the date, who decided, and why. When a
question is answered, move it to "Decided" and update the code/config.

## Open questions (for Deena)

| # | Raised | Question | Affects |
|---|--------|----------|---------|
| 2 | 2026-10-22 | **Broadband uses 2010 tracts** (`TRACT_FIPS10`). Workplan step 4a.ii says to flag this. How should we harmonize to 2020 tracts (e.g., NHGIS 2010->2020 tract crosswalk with household weights)? | `clean_NaNDA_broadband.R`; merge |
| 3 | 2026-10-22 | **Broadband speed units.** Docs say kbps, but values (~8.5 in 2014) look like Mbps (FCC Form 477 units). Confirm before labeling. | `measures.csv` unit |
| 4 | 2026-10-22 | **Broadband adoption is a 0-5 category**, with real data only 2015-2018. Keep as ordinal code? | Analysis |
| 5 | 2026-10-22 | **Childcare export has no price or capacity fields** and is a current snapshot only. What source should we use for prices and capacity, and for which years? | `clean_OHDCY.R` |
| 6 | 2026-10-22 | Workplan's "professional development schools" -> NaNDA "Personal Development Schools" (`den_develscho`)? | `measures.csv` |

## Decided

| # | Date | Decision | By | Reason |
|---|------|----------|----|--------|
| 1 | 2026-10-22 | All clean data stay at **census-tract level**; no PUMA aggregation. Workplan PUMA instructions were meant to be removed. | Workplan owner | Workplan Section I and measure-specific instructions |

## How workplan steps were adapted from PUMA to tract level

| Workplan step | Tract-level version |
|---|---|
| 3. Get list of 10 Cuyahoga PUMAs | `county_tracts()` gets all Cuyahoga tracts (tigris, step 4a.ii's `tr20`); `check_panel()` reports coverage against it |
| 4a.iii-v. Crosswalk, weights, weighted medians | Not needed: data stay at native tract level |
| 4a.vii. `nrow()` = 10 x years | `check_panel()` requires `nrow()` = tracts x years and no duplicate tract-years |
| 4b. Address -> PUMA | `geocode_to_tract()`: Census geocoder for lat/long, spatial join (`st_within`) to 2020 tracts; `aggregate_addresses()`: `sum()` for counts, `median()` across addresses for rates |
| 4d. Name `PUMA`, `year` | `GEOID20` (as in the workplan's example table) and `year` |
| IV.4 `table(PUMA, year)` | `table(GEOID20, year)` (collapsible in report) + summary of years per tract |
| IV.6c Stats by PUMA and year | Stats by year. By tract and year would be one value per group |
| IV.6e Trend plot | Points for each tract-year plus a line through the yearly mean. A plain `geom_line()` through hundreds of tracts zig-zags vertically |
| IV.6f Trend by PUMA | One line per tract, coloured by tract; legend hidden (hundreds of tracts) |
| IV.6a `plot(hist(x))` | `hist(x)`. `plot(hist())` draws the histogram twice |
