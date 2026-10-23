# =============================================================================
# SETUP -- every script starts with: source(here::here("scripts", "00_setup.R"))
# -----------------------------------------------------------------------------
# Loads core packages, project settings, and every function in R/.
# Packages only needed for some steps (tigris, sf, tidygeocoder, openxlsx,
# rstatix, lme4, performance) are checked when those functions run.
# =============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(readr)
  library(stringr)
})

source(here::here("config", "settings.R"))
for (f in list.files(here::here("R"), pattern = "\\.R$", full.names = TRUE)) source(f)
