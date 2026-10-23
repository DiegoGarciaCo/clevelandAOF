# =============================================================================
# CODEBOOK: build LQ1_Supplemental_Data_Codebook.xlsx from config/measures.csv
# -----------------------------------------------------------------------------
# Write definitions and limitations in measures.csv; this function turns them
# into the Excel codebook. Geography and Year(s) are read from the clean files
# themselves, so they always match the data that was actually produced.
# =============================================================================

write_codebook <- function(file = CODEBOOK_FILE) {
  need_pkgs("openxlsx")
  sources  <- read_sources()
  measures <- read_measures()
  clean    <- load_clean_all()

  # Years with at least one non-missing value, and the ID column, per clean_var
  observed <- dplyr::bind_rows(lapply(clean, function(df) {
    id <- intersect(c("GEOID20", "GEOID10"), names(df))[1]
    vars <- setdiff(names(df), c(id, "year"))
    dplyr::bind_rows(lapply(vars, function(v) data.frame(
      clean_var = v,
      years_observed = year_span(df$year[!is.na(df[[v]])]),
      id_col = id
    )))
  }))
  if (!nrow(observed)) observed <- data.frame(clean_var = character(), years_observed = character(), id_col = character())

  geo_label <- function(id) dplyr::case_when(
    id == "GEOID20" ~ "Census tract (2020 vintage)",
    id == "GEOID10" ~ "Census tract (2010 vintage)",
    TRUE            ~ "Not yet cleaned"
  )

  cb <- measures |>
    dplyr::left_join(dplyr::select(sources, source_id, source_name, status), by = "source_id") |>
    dplyr::left_join(observed, by = "clean_var") |>
    dplyr::transmute(
      `Data Source`          = source_name,
      `Source Variable Name` = raw_var,
      `Clean Variable Name`  = clean_var,
      `Label`                = label,
      `Definition`           = definition,
      `Unit`                 = unit,
      `Geography`            = geo_label(id_col),
      `Year(s)`              = dplyr::coalesce(years_observed, paste0("Not yet cleaned (", status, ")")),
      `Notes / Limitations`  = notes_limitations
    )

  src_sheet <- dplyr::select(sources, source_id, source_name, url, native_geography,
                             geo_vintage, years_available, raw_file, clean_file, status, notes)

  wb <- openxlsx::createWorkbook()
  header <- openxlsx::createStyle(textDecoration = "bold", fgFill = "#DDE5EE", wrapText = TRUE,
                                  valign = "top", border = "bottom")
  wrap <- openxlsx::createStyle(wrapText = TRUE, valign = "top")
  add_sheet <- function(name, df, widths) {
    openxlsx::addWorksheet(wb, name)
    openxlsx::writeData(wb, name, df, headerStyle = header)
    openxlsx::addStyle(wb, name, wrap, rows = seq_len(nrow(df)) + 1, cols = seq_along(df), gridExpand = TRUE)
    openxlsx::setColWidths(wb, name, cols = seq_along(df), widths = widths)
    openxlsx::freezePane(wb, name, firstRow = TRUE)
  }
  add_sheet("Measures", cb,        c(30, 24, 24, 30, 60, 16, 24, 18, 60))
  add_sheet("Sources",  src_sheet, c(18, 40, 40, 14, 10, 16, 32, 22, 14, 50))

  dir.create(dirname(file), showWarnings = FALSE, recursive = TRUE)
  openxlsx::saveWorkbook(wb, file, overwrite = TRUE)
  message("Codebook written: ", file)
  invisible(cb)
}
