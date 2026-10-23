# =============================================================================
# RUN EVERYTHING
# -----------------------------------------------------------------------------
# 1. Runs every cleaning script whose status is "ready" in config/sources.csv
# 2. Rebuilds the codebook (outputs/LQ1_Supplemental_Data_Codebook.xlsx)
# 3. Knits the merge + descriptives report into data/supplemental_clean/
#    (workplan IV.7)
#
# Each script runs in its own environment, so one script can't accidentally
# use objects left behind by another.
# =============================================================================

source(here::here("scripts", "00_setup.R"))

ready <- filter(read_sources(), status == "ready")
skipped <- filter(read_sources(), status != "ready")
if (nrow(skipped)) message("Skipping (not ready): ",
                           paste0(skipped$source_id, " [", skipped$status, "]", collapse = ", "))

for (script in ready$script) {
  source(file.path(PATHS$scripts, "clean", script), local = new.env())
}

write_codebook()

rmarkdown::render(
  file.path(PATHS$scripts, "analysis", "merge_descriptives.Rmd"),
  output_dir = REPORT_DIR,
  knit_root_dir = here::here(),
  quiet = TRUE
)
message("Report written to ", file.path(REPORT_DIR, "merge_descriptives.html"))
