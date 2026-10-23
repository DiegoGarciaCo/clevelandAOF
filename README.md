# LQ1 Supplemental SDoW Data

Download, cleaning, and documentation of supplemental **Social Determinants of
Work (SDoW)** measures for Cleveland / Cuyahoga County, Ohio (Learning Question
1). Everything is kept at **census-tract level**.

This repository is a small, config-driven ETL project. The short version:

> `config/` says **what** to process, `R/` says **how**, `scripts/` **does it**,
> `data/` holds the data, and `outputs/` holds the things people read.

The formal workplan is in `docs/workplan/`. Every place where the code departs
from it (chiefly: PUMA → census tract) is documented with dates in
`docs/decisions_log.md`.

---

## Contents

1. [What this project produces](#what-this-project-produces)
2. [First hour: get it running](#first-hour-get-it-running)
3. [How the project fits together](#how-the-project-fits-together)
4. [Full directory map](#full-directory-map)
5. [The `R/` function reference](#the-r-function-reference)
6. [The config files](#the-config-files)
7. [The clean-data contract](#the-clean-data-contract)
8. [What happens when you run `run_all.R`](#what-happens-when-you-run-run_allr)
9. [Adding a new data source](#adding-a-new-data-source)
10. [Other common tasks](#other-common-tasks)
11. [Naming conventions](#naming-conventions)
12. [Current source status](#current-source-status)
13. [Troubleshooting](#troubleshooting)
14. [Glossary](#glossary)

---

## What this project produces

| Deliverable                                                                | Path                                                      | Built by                                  |
| -------------------------------------------------------------------------- | --------------------------------------------------------- | ----------------------------------------- |
| One clean dataset per source (CSV + RData)                                 | `data/supplemental_clean/supp_<source_id>.csv` / `.RData` | `scripts/clean/clean_<source_id>.R`       |
| Merged analysis file, 2020 tracts                                          | `data/supplemental_clean/supp_all_SDoW.csv` / `.RData`    | `scripts/analysis/merge_descriptives.Rmd` |
| Excel codebook (measure definitions, units, geography, years, limitations) | `outputs/LQ1_Supplemental_Data_Codebook.xlsx`             | `R/codebook.R`                            |
| Descriptive-statistics HTML report                                         | `data/supplemental_clean/merge_descriptives.html`         | `scripts/analysis/merge_descriptives.Rmd` |

The codebook and report are generated from the data and config — **do not edit
them by hand**. Edit `config/measures.csv` and the cleaning scripts instead.

---

## First hour: get it running

1. **Open the project**, not just the folder: double-click
   `LQ1_supplemental.Rproj` (or _File → Open Project_ in RStudio). All paths are
   built with `here::here()`, which resolves to the folder containing the
   `.Rproj` file, so nothing depends on your working directory or OS.
2. **Install packages once:**

   ```r
   install.packages(c(
     "here", "dplyr", "tidyr", "readr", "stringr",   # always used
     "haven", "openxlsx",                            # reading .dta, codebook
     "ggplot2", "rstatix", "lme4", "performance",    # descriptives
     "rmarkdown", "knitr",                           # report
     "tigris", "sf", "tidygeocoder"                  # geography / geocoding
   ))
   ```

   Only the first line is loaded up front; the rest are checked lazily by the
   functions that need them (`need_pkgs()` in `R/geo.R`), so a missing optional
   package gives a clear "install this" message rather than a cryptic error.
3. **Run the project:** open `run_all.R` and source it, or from a terminal:

   ```sh
   Rscript run_all.R
   ```

   This cleans every source whose `status` is `ready`, rebuilds the codebook,
   and knits the report.
4. **Orient yourself:** read `docs/decisions_log.md` (what was decided and what
   is still open), then the workplan DOCX in `docs/workplan/`. The decisions log
   is the fastest way to understand _why_ the code looks the way it does.

The first run needs internet access: `tigris` downloads the county tract list
and `tidygeocoder` calls the Census geocoder. Both results are cached in
`data/reference/`, so later runs are offline-friendly.

---

## How the project fits together

```
                 config/settings.R      config/sources.csv      config/measures.csv
                        │                      │                        │
                        └──────────────┬───────┴────────────────────────┘
                                       │  (what to process)
                                       ▼
  scripts/00_setup.R ── loads packages, settings, and every function in R/
                                       │
                                       ▼
  scripts/clean/clean_<source_id>.R    source-specific prep only
        (import → explore → reshape/recode → clean_source())
                                       │
                         clean_source() │  R/pipeline.R
                                       ▼
             R/geo.R      standardize tract ID, filter to Cuyahoga
             R/checks.R   check_panel(): duplicates, complete panel, numeric
             R/io.R       save CSV + RData
                                       │
                                       ▼
                 data/supplemental_clean/supp_<source_id>.csv / .RData
                                       │
                    ┌──────────────────┴──────────────────┐
                    ▼                                     ▼
      R/codebook.R → outputs/*.xlsx          merge_descriptives.Rmd
                                             R/describe.R → supp_all_SDoW +
                                                            merge_descriptives.html
```

Key idea: **a cleaning script only handles what is unique to its source.** Every
shared step (tract IDs, county filter, year filter, column order/renaming,
structural checks, saving) happens inside `clean_source()`. That is why adding a
source is mostly a config exercise plus a short prep block.

---

## Full directory map

```
LQ1_supplemental/
├── README.md                      ← you are here
├── LQ1_supplemental.Rproj         ← RStudio project file; defines the project root
├── run_all.R                      ← end-to-end runner: clean → codebook → report
│
├── config/                        ← WHAT we process (edit these for most changes)
│   ├── settings.R                 ← study years, county FIPS, target tract vintage, PATHS
│   ├── sources.csv                ← registry: one row per data source (URL, raw file, status…)
│   └── measures.csv               ← registry: one row per measure (names, definitions, units…)
│
├── R/                             ← HOW we process (reusable functions, no side effects)
│   ├── pipeline.R                 ← clean_source(): the standard cleaning steps
│   ├── geo.R                      ← tract ID normalization, county filter, county tract list,
│   │                                geocoding + address→tract aggregation
│   ├── checks.R                   ← check_panel(): structural validation before saving
│   ├── io.R                       ← raw file lookup; save/load clean files
│   ├── registry.R                 ← reads sources.csv / measures.csv; source & measure lookup
│   ├── codebook.R                 ← builds the Excel codebook from measures.csv + clean data
│   └── describe.R                 ← merge + descriptive statistics (workplan Section IV)
│
├── scripts/                       ← DOES IT
│   ├── 00_setup.R                 ← the one line every script starts with: packages + settings + R/
│   ├── clean/
│   │   ├── _TEMPLATE_clean_source.R   ← copy this when adding a source
│   │   ├── clean_NaNDA_broadband.R    ← NaNDA broadband (2010 tracts; ready)
│   │   ├── clean_NaNDA_workforce.R    ← NaNDA training/vocational schools (not downloaded)
│   │   ├── clean_NEOCANDO.R           ← NEOCANDO skeleton (not downloaded)
│   │   └── clean_OHDCY.R              ← Ohio child care (blocked; shows address-level workflow)
│   └── analysis/
│       └── merge_descriptives.Rmd     ← merges clean files, runs checks, writes report
│
├── data/
│   ├── supplemental_raw/          ← raw data, NEVER edited in place
│   │   └── <source_id>/
│   │       ├── <raw_file>         ← exactly the filename listed in sources.csv
│   │       └── documentation/     ← that source's codebook, PDFs, export notes
│   ├── supplemental_clean/        ← generated: supp_*.csv/.RData, supp_all_SDoW, report HTML
│   └── reference/                 ← generated caches (safe to delete; rebuilt on demand)
│       ├── tracts2020_39035.csv           ← Cuyahoga 2020 tract list (tigris cache)
│       └── OHDCY_programs_geocoded.csv    ← geocoded child-care addresses
│
├── outputs/                       ← things people read (not derived row-level data)
│   └── LQ1_Supplemental_Data_Codebook.xlsx
│
└── docs/
    ├── decisions_log.md           ← dated judgment calls + open questions
    └── workplan/
        └── Quant_LQ1_Supplemental_Data_Download_and_Cleaning_Workplan.docx
```

Notes on generated files (none of these should be committed as inputs):

- `data/reference/*` are caches. Deleting them only costs a re-download.
- `load_clean_all()` reads **every** `supp_*.RData` in `supplemental_clean/`,
  except `supp_all_*`. Old outputs for a source you have since disabled will
  still appear in the codebook/report until you delete that file.
- `.RData` objects are named after their file (e.g. `supp_NaNDA_broadband`), so
  `load("supp_NaNDA_broadband.RData")` gives you exactly that object.
- CSVs are written with `na = ""`.

---

## The `R/` function reference

### `R/registry.R` — config access

The two CSVs are the single source of truth. Scripts never hard-code file or
variable names.

| Function                  | Purpose                                                                         |
| ------------------------- | ------------------------------------------------------------------------------- |
| `read_sources()`          | Read `config/sources.csv` (all columns as character).                           |
| `read_measures()`         | Read `config/measures.csv`.                                                     |
| `get_source(source_id)`   | One source's row as a list; errors unless the ID appears exactly once.          |
| `get_measures(source_id)` | That source's measure rows; errors if none or if `clean_var` is duplicated.     |
| `id_col_name(vintage)`    | `2020 → "GEOID20"`, `2010 → "GEOID10"`. Encodes the vintage in the column name. |

### `R/io.R` — files

| Function                    | Purpose                                                                                    |
| --------------------------- | ------------------------------------------------------------------------------------------ |
| `raw_dir(source_id)`        | `data/supplemental_raw/<source_id>/`.                                                      |
| `raw_file(source_id, file)` | Full path to the raw file named in `sources.csv`; stops with a helpful message if missing. |
| `load_rda(path)`            | Loads the single object in an `.rda`/`.RData` file and returns it.                         |
| `save_clean(df, name)`      | Writes `<name>.csv` and `<name>.RData` into `supplemental_clean/`.                         |
| `load_clean_all()`          | All clean `supp_*` files as a named list (excludes `supp_all_*`).                          |

### `R/geo.R` — geography

| Function                                         | Purpose                                                                                                                                                                                                         |
| ------------------------------------------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `standardize_tract(x, format)`                   | Builds an 11-character GEOID. `format` is required and must be `"geoid"` (already 11 digits), `"tract6"` (6-digit tract code), or `"tract_number"` (`"1011.01"` style). Errors on anything it cannot normalize. |
| `filter_county(df, id_col)`                      | Keeps rows whose GEOID starts with `39` (Ohio) + `035` (Cuyahoga).                                                                                                                                              |
| `county_tracts(vintage)`                         | All county tract GEOIDs for a vintage, via `tigris`, cached in `data/reference/`. Returns `NULL` (with a message) if `tigris` is missing or offline.                                                            |
| `geocode_to_tract(df, street, city, state, zip)` | Census-geocodes addresses, spatially joins points to 2020 tracts, adds `row_id`, `lat`, `long`, `GEOID20`. Warns if >5% are unmatched.                                                                          |
| `aggregate_addresses(df, source_id)`             | Collapses address rows to tract-year using `agg_method` (`sum` for counts, `median` for rates/prices).                                                                                                          |
| `need_pkgs(pkgs)`                                | Friendly "install these packages" error for optional dependencies.                                                                                                                                              |

### `R/checks.R` — validation

| Function                             | Purpose                                                                                                                                                                                                                      |
| ------------------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `check_panel(df, id_col)`            | Stops on duplicate tract-years, `nrow() != tracts × years`, malformed IDs, years outside `STUDY_YEARS`, or non-numeric measures. Then reports tract coverage vs. the full county list and prints % missing per measure-year. |
| `report_tract_coverage(ids, id_col)` | Compares observed tracts with the county's full tract list for that vintage; warns about IDs not in the list (usually a vintage mismatch).                                                                                   |
| `missing_by_year(df, measure_cols)`  | Percent missing per measure per year.                                                                                                                                                                                        |
| `year_span(years)`                   | Compact label such as `"2015-2018, 2020"`.                                                                                                                                                                                   |

### `R/pipeline.R` — the standard pipeline

| Function                                                                 | Purpose                                                                                                                                                                                                                                   |
| ------------------------------------------------------------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `clean_source(df, source_id, id_col_raw, year_col_raw, id_format, save)` | Renames `raw_var → clean_var`, standardizes the tract ID, filters to Cuyahoga + `STUDY_YEARS`, orders columns (ID, `year`, measures in `measures.csv` order), runs `check_panel()`, saves. Set `save = FALSE` to inspect without writing. |

`clean_source()` does **not** deduplicate, aggregate, or add missing tract-years.
Those are the source script's job (use `tidyr::complete()`).

### `R/codebook.R` — Excel codebook

| Function               | Purpose                                                                                                                                                                           |
| ---------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `write_codebook(file)` | Joins `measures.csv` + `sources.csv` + observed years from the clean files into two sheets: **Measures** and **Sources**. Geography and years reflect what was actually produced. |

### `R/describe.R` — merge and descriptives

| Function                                       | Purpose                                                                                                                                                            |
| ---------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `merge_clean(clean_list, id_col)`              | Full outer join of all clean files keyed on `year` + `id_col`; skips files on another tract vintage with a message.                                                |
| `describe_measure(df, measure, id_col, label)` | Workplan IV.6 a–f for one measure: histogram, overall summary stats, stats by year, ICC (null model with tract random intercept), trend plot, trend plot by tract. |

---

## The config files

### `config/settings.R`

Project-wide constants. If you are about to type one of these values in a
script, use the setting instead.

| Object                                     | Meaning                                                                                      |
| ------------------------------------------ | -------------------------------------------------------------------------------------------- |
| `STUDY_YEARS`                              | Years kept in every clean dataset (`2015:2025`).                                             |
| `STATE_FIPS`, `COUNTY_FIPS`, `COUNTY_NAME` | `"39"`, `"035"`, `"Cuyahoga"`.                                                               |
| `TARGET_TRACT_VINTAGE`                     | Vintage used for the merge (`2020`). Clean files on other vintages are saved but not merged. |
| `PATHS`                                    | Named absolute paths (`config`, `raw`, `clean`, `reference`, `outputs`, `scripts`).          |
| `CODEBOOK_FILE`, `REPORT_DIR`              | Output locations. The report intentionally lands in `supplemental_clean/` (workplan IV.7).   |

### `config/sources.csv` — one row per data source

| Column             | Meaning                                                                                                                      |
| ------------------ | ---------------------------------------------------------------------------------------------------------------------------- |
| `source_id`        | Unique key. Used for the raw folder, script name, patch/measure lookup, and clean filename. Format `<Organization>_<topic>`. |
| `source_name`      | Human-readable title (appears in the codebook).                                                                              |
| `url`              | Where a human downloads the data.                                                                                            |
| `native_geography` | `tract`, `address`, `county`, … — what the raw data is keyed on.                                                             |
| `geo_vintage`      | `2020`, `2010`, or `TBD`. Drives the output ID column name (`GEOID20`/`GEOID10`).                                            |
| `years_available`  | Free text, for humans.                                                                                                       |
| `raw_file`         | Filename **inside** `data/supplemental_raw/<source_id>/`. Can be `TBD` before download.                                      |
| `clean_file`       | Output basename, no extension, by convention `supp_<source_id>`.                                                             |
| `script`           | Filename in `scripts/clean/`.                                                                                                |
| `status`           | `ready`, `not_downloaded`, `blocked`, or `not_usable`. **Only `ready` runs in `run_all.R`.**                                 |
| `notes`            | Caveats and next actions.                                                                                                    |

Status meanings:

- `ready` — runs end to end and passes `check_panel()`.
- `not_downloaded` — code may exist, but the raw file is absent.
- `blocked` — waiting on an external answer/data issue; script may deliberately `stop()`.
- `not_usable` — available only at a coarser geography than tracts (record that geography in `notes`; do not clean it — workplan step 4c).

### `config/measures.csv` — one row per measure

| Column              | Meaning                                                                                               |
| ------------------- | ----------------------------------------------------------------------------------------------------- |
| `source_id`         | Must match a row in `sources.csv`.                                                                    |
| `raw_var`           | Column name **after** the script's prep step (for address data: after aggregation).                   |
| `clean_var`         | Final column name: `snake_case`, short topic prefix (`bb_`, `train_`), unique within the source.      |
| `label`             | Human-readable label for tables and plots.                                                            |
| `definition`        | Precise definition: numerator, denominator, source program.                                           |
| `unit`              | Unit **as documented**, plus a caveat if the unit is uncertain.                                       |
| `agg_method`        | Address-level sources only: `sum` (counts) or `median` (rates/prices). Blank for tract-level sources. |
| `notes_limitations` | Everything a user must know (coverage, vintage, known issues, open questions).                        |

Column order in `measures.csv` **is** the output column order in the clean file.
`raw_var` names are checked against the prepared data at run time, so a typo
fails fast with a list of missing columns.

---

## The clean-data contract

Every file in `data/supplemental_clean/` obeys the same structure, enforced by
`check_panel()` before saving:

- **Rows:** one row per census tract per year. No duplicate tract-years.
- **Complete panel:** `nrow() == n_tracts × n_distinct(years_present)`. Every
  tract has a row for every year represented in that dataset; years without
  data must exist as `NA` rows (add them with `tidyr::complete()` in the prep
  step). Note this is about internal consistency, not about covering all of
  `STUDY_YEARS`.
- **Columns:** `GEOID20` (or `GEOID10` for a non-target vintage), then `year`
  (integer), then the measures in `measures.csv` order under their `clean_var`
  names.
- **Scope:** Cuyahoga County only; `year %in% STUDY_YEARS` only.
- **Types:** every measure column is numeric. Missing values are `NA`, not
  sentinel codes such as `-99`.

Any file failing a check stops the run with a message naming the fix.

---

## What happens when you run `run_all.R`

1. Sources `scripts/00_setup.R` → loads `dplyr`, `tidyr`, `readr`, `stringr`,
   then `config/settings.R`, then every file in `R/` (alphabetical, so order
   within `R/` must not matter).
2. Reads `sources.csv`, messages which sources are skipped and why.
3. For each `ready` source, sources its script in a **fresh environment**
   (`local = new.env()`), so no script can accidentally depend on objects left
   behind by another. Each script runs its own `source(00_setup.R)` again.
4. Runs `write_codebook()`, which reloads all clean files and writes
   `outputs/LQ1_Supplemental_Data_Codebook.xlsx`.
5. Renders `scripts/analysis/merge_descriptives.Rmd` with the project root as
   knit root, writing `data/supplemental_clean/merge_descriptives.html`. The
   notebook also rewrites `supp_all_SDoW.csv/.RData` from whatever clean files
   currently exist.

You can run any single cleaning script on its own (`source("scripts/clean/clean_NaNDA_broadband.R")`);
the codebook and report only read files from disk, so they can be rebuilt
without re-running every source.

---

## Adding a new data source

This is the main extension point of the project. Adding a source touches **four
places**: the raw folder, `sources.csv`, `measures.csv`, and one cleaning
script. You never edit `run_all.R` or the shared `R/` code.

### Step 0 — pick a `source_id`

Use `<Organization>_<topic>` in lower-case-with-underscores style, e.g.
`NaNDA_broadband`, `OHDCY_childcare`. The **same string** is used in:

```
data/supplemental_raw/<source_id>/          raw folder
config/sources.csv:source_id                registry key
config/measures.csv:source_id               measure rows
scripts/clean/clean_<source_id>.R           script name
sources.csv:clean_file = supp_<source_id>   output name
```

### Step 1 — add the raw data and its documentation

```
data/supplemental_raw/<source_id>/
├── <raw_file>                 ← exact filename you will put in sources.csv
└── documentation/             ← codebook PDF, technical docs, export README
```

Raw data is **read-only**. Never edit it in place or write derived files here;
all transformations happen in the cleaning script.

### Step 2 — register the source in `config/sources.csv`

Add one row. Minimal example for a downloadable tract-level CSV:

```csv
source_id,source_name,url,native_geography,geo_vintage,years_available,raw_file,clean_file,script,status,notes
Agency_topic,"Full descriptive title",https://example.org/data,tract,2020,2016-2024,agency_topic.csv,supp_Agency_topic,clean_Agency_topic.R,ready,Short caveat.
```

Set `status` to something other than `ready` while you are still writing the
script; flip it to `ready` only when it runs cleanly.

### Step 3 — register every measure in `config/measures.csv`

One row per output variable:

```csv
source_id,raw_var,clean_var,label,definition,unit,agg_method,notes_limitations
Agency_topic,raw_col_name,agency_short_name,Human-readable label,"Numerator / denominator / source program.",Percent,,Coverage and known limitations.
```

Rules:

- `raw_var` must be the column name **after** your prep step (not necessarily
  the raw file's name, but usually it is).
- `clean_var` must be unique within the source and is used for the final column.
- Leave `agg_method` blank for tract-level data; use `sum` or `median` for
  address-level data.
- Write the definition and limitations here, not in the script — the codebook
  is generated from this file.

### Step 4 — copy the template and fill in the prep step

```sh
cp scripts/clean/_TEMPLATE_clean_source.R scripts/clean/clean_Agency_topic.R
```

The template has four labelled sections. Only sections 1–3 are source-specific:

1. **Import** — pick a reader:
   `readr::read_csv()`, `haven::read_dta()`, `load_rda()`, or
   `readxl::read_excel()`, usually wrapped in `raw_file(SOURCE_ID)`.
2. **Explore** — interactive-only `glimpse()`/`summary()` for your own
   understanding; record what you learn in `measures.csv` notes.
3. **Source-specific preparation** — produce **long data**: one row per tract
   and year, with a tract ID column, a year column, and one column per measure
   named exactly as `raw_var`. Typical work:
   - reshape wide year columns with `tidyr::pivot_longer()`,
   - recode categories / factor labels to numeric codes,
   - convert sentinel missing codes (`-99`, `""`) to `NA`,
   - `haven::zap_labels()` for Stata files,
   - `tidyr::complete(<id_col>, year)` when some tract-years have no row.
4. **Standard pipeline** — always the same call:

   ```r
   clean_source(
     prepped,
     source_id    = SOURCE_ID,
     id_col_raw   = "tract_id_column",
     year_col_raw = "year",
     id_format    = "geoid"   # or "tract6" / "tract_number"
   )
   ```

Use the existing scripts as patterns:

| Pattern                                             | Example script                              |
| --------------------------------------------------- | ------------------------------------------- |
| Already long, simple rename/zap labels              | `clean_NaNDA_workforce.R`                   |
| Factor labels → numeric codes, non-target vintage   | `clean_NaNDA_broadband.R`                   |
| Wide export → long, multiple measures from one file | `clean_NEOCANDO.R` (skeleton)               |
| Address-level → geocode → aggregate to tract        | `clean_OHDCY.R` (workflow, blocked on data) |

#### Address-level sources in more detail

When `native_geography = address`, the path is:

```
program/address rows
  → geocode_to_tract()        adds lat/long + GEOID20, warns on unmatched
  → aggregate_addresses()     sum/median per tract-year per agg_method
  → tidyr::complete()         add missing tract-year rows
  → clean_source()            same standard pipeline
```

Geocoding is slow and needs internet, so cache the result in
`data/reference/<source_id>_geocoded.csv` (see `clean_OHDCY.R`). Delete the
cache if the address file changes.

#### When the source is not tract-level at all

If the finest available geography is coarser than a census tract (county,
ZIP-only without crosswalk, city), do **not** force it. Set `status =
not_usable` in `sources.csv`, record the actual geography and reason in
`notes`, and leave it out of cleaning (workplan step 4c). A `status =
not_usable` row can stay in `measures.csv` with `TODO` definitions for
documentation purposes.

### Step 5 — run and verify

```r
source("scripts/clean/clean_Agency_topic.R")   # fast feedback loop
source("run_all.R")                            # full pipeline
```

Success looks like:

- `check_panel() passed: N rows = T tracts x Y years`
- a coverage line like `Tract coverage: 215 of 218 Cuyahoga 2020 tracts present`
- no duplicate/vintage warnings,
- a new `supp_<source_id>.csv`/`.RData`,
- the measure's row in the codebook showing a real `Year(s)` value,
- the measure appearing in the report.

If `check_panel()` fails, the message names the cause; the fix is almost always
`tidyr::complete()` in section 3 (missing tract-years) or a `raw_var` typo.

### Step 6 — record decisions

Add any judgment call (geography mismatch, unit ambiguity, recodes,
exclusions) to `docs/decisions_log.md` with the date, the decision, and why. If
it is still unresolved, put it under **Open questions** instead.

---

## Other common tasks

| I want to…                                     | Do this                                                                                                                                                           |
| ---------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Add a measure to an existing source            | Add a row to `measures.csv`; ensure the prep step produces that `raw_var`; rerun the source and `run_all.R`.                                                      |
| Rename a final column                          | Change `clean_var` in `measures.csv` (this renames it everywhere downstream).                                                                                     |
| Fix a definition/limitation                    | Edit `measures.csv`; rebuild the codebook.                                                                                                                        |
| Change study years                             | Edit `STUDY_YEARS` in `settings.R`. Clean scripts filter on it; `check_panel()` enforces it. Rerun all sources.                                                   |
| Change the merge vintage                       | Edit `TARGET_TRACT_VINTAGE`; **every** source must then be on that vintage (or be excluded). A crosswalk is required — see open question #2 in the decisions log. |
| Disable a source                               | Set `status` to anything ≠ `ready`; delete its `supp_*` files if you want it out of the codebook/report too.                                                      |
| Inspect a source without writing               | Call `clean_source(..., save = FALSE)`.                                                                                                                           |
| Refresh cached tract list / geocodes           | Delete the relevant file in `data/reference/`.                                                                                                                    |
| Look up a source's download URL                | `config/sources.csv`, column `url`.                                                                                                                               |
| Understand why a workplan step looks different | `docs/decisions_log.md`.                                                                                                                                          |

---

## Naming conventions

| Thing              | Convention                                     | Example                                   |
| ------------------ | ---------------------------------------------- | ----------------------------------------- |
| Source ID          | `<Organization>_<topic>`, identical everywhere | `NaNDA_broadband`                         |
| Raw folder         | `data/supplemental_raw/<source_id>/`           | `.../NaNDA_broadband/`                    |
| Cleaning script    | `scripts/clean/clean_<source_id>.R`            | `clean_NaNDA_broadband.R`                 |
| Clean file         | `supp_<source_id>.csv` / `.RData`              | `supp_NaNDA_broadband.csv`                |
| Tract ID column    | `GEOID20` / `GEOID10`, by vintage              | `GEOID20`                                 |
| Year column        | `year` (integer)                               | `2018`                                    |
| Measure columns    | `snake_case`, short topic prefix               | `bb_download_speed`, `train_beauty_per1k` |
| CSV missing values | empty string (`na = ""`)                       |                                           |

Naming the tract column by vintage means 2010 and 2020 tracts **cannot** be
merged by accident: `merge_clean()` only joins files containing the target ID
column and reports the rest as skipped.

---

## Current source status

Always trust `config/sources.csv` over this table.

| Source            | Geography   | Status           | What's left                                                                                                                      |
| ----------------- | ----------- | ---------------- | -------------------------------------------------------------------------------------------------------------------------------- |
| `NaNDA_broadband` | 2010 tracts | `ready`          | Harmonize 2010 → 2020 tracts before merging (open question #2). Confirm speed units (#3) and adoption coding (#4).               |
| `NaNDA_workforce` | 2020 tracts | `not_downloaded` | Download `nanda_trainvoc_Tract20_1990-2022_01P.dta`, run, verify. Confirm "personal development schools" mapping (#6).           |
| `NEOCANDO`        | TBD         | `not_downloaded` | Download export, confirm vintage, fill TODO definitions in `measures.csv`, implement reshape in `clean_NEOCANDO.R`.              |
| `OHDCY`           | addresses   | `blocked`        | Current export has no price or capacity fields and is a snapshot only (open question #5). Geocoding workflow is already written. |

Open questions are tracked in `docs/decisions_log.md`; resolved decisions move
to its **Decided** table.

---

## Troubleshooting

| Symptom                                                              | Cause / fix                                                                                                                                            |
| -------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `Raw file not found: …`                                              | The file is missing or misnamed. Put it at the exact path `sources.csv` implies (`raw_file` inside `data/supplemental_raw/<source_id>/`).              |
| `Columns listed for … are not in the data: …`                        | `raw_var` in `measures.csv` doesn't match the column names your prep step produces. Fix the prep or the config.                                        |
| `check_panel() failed: … nrow() is X but should be T x Y`            | Missing tract-year rows. Add `tidyr::complete(<id_col>, year)` in the prep step.                                                                       |
| `geo_vintage is not set for this source`                             | Fill `geo_vintage` in `sources.csv` (`2020`/`2010`).                                                                                                   |
| `N tract ID(s) not in the … county tract list (vintage mismatch?)`   | The data is on a different tract vintage than the ID column claims, or contains non-Cuyahoga tracts. Check the source docs; a crosswalk may be needed. |
| `tigris not installed -- skipping tract coverage check`              | Optional; install `tigris` for coverage reporting. The run still succeeds.                                                                             |
| `Could not download tract list (…)`                                  | Offline. Coverage check is skipped; clean data are still produced.                                                                                     |
| `Install required package(s) first: …`                               | Run the printed `install.packages()` command.                                                                                                          |
| Geocoding takes forever / `OHDCY` uses old addresses                 | Delete `data/reference/OHDCY_programs_geocoded.csv` and rerun.                                                                                         |
| A stale measure appears in the codebook/report                       | `load_clean_all()` reads every `supp_*.RData`. Delete the file for the disabled source.                                                                |
| Script stops with `stop("OHDCY: no price or capacity fields yet …")` | Intentional. See open question #5; don't remove the guard until the data exist.                                                                        |
| Report knitting fails on `rstatix`/`lme4`/`performance`              | Install those packages. They are only needed for `describe_measure()`.                                                                                 |

---

## Glossary

| Term                        | Meaning here                                                                                                                  |
| --------------------------- | ----------------------------------------------------------------------------------------------------------------------------- |
| **SDoW**                    | Social Determinants of Work — the measure family this project compiles.                                                       |
| **LQ1**                     | Learning Question 1, the research question this data supports.                                                                |
| **Tract**                   | Census tract; the fixed unit of analysis for all clean data.                                                                  |
| **Vintage**                 | The decennial boundary set a tract ID belongs to (2010 vs. 2020). IDs are not comparable across vintages without a crosswalk. |
| **GEOID**                   | 11-digit census geography ID: 2-digit state + 3-digit county + 6-digit tract.                                                 |
| **Panel**                   | The required shape: one row per tract-year, no gaps within the years present.                                                 |
| **`raw_var` / `clean_var`** | Column name in the prepared data / final output column name.                                                                  |
| **`agg_method`**            | How address-level values collapse to a tract: `sum` for counts, `median` for rates/prices.                                    |
| **Ready**                   | Status flag meaning "this source runs cleanly in `run_all.R`".                                                                |
| **PUMA**                    | Public Use Microdata Area; the original workplan geography, replaced by tracts (decision #1).                                 |
