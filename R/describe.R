# =============================================================================
# MERGE + DESCRIPTIVES (workplan Section IV, tract level)
# Used by scripts/analysis/merge_descriptives.Rmd
# =============================================================================

#' Workplan IV.3: merge all clean files with merge(..., all = TRUE) so no rows are lost.
#' Only files keyed on the same tract vintage (id_col) can be merged; others are
#' skipped with a message.
merge_clean <- function(clean_list, id_col) {
  usable  <- Filter(function(df) id_col %in% names(df), clean_list)
  skipped <- setdiff(names(clean_list), names(usable))
  if (length(skipped)) message("Not merged (not on ", id_col, "): ", paste(skipped, collapse = ", "))
  if (!length(usable)) return(NULL)
  Reduce(function(a, b) merge(a, b, by = c("year", id_col), all = TRUE), usable)
}

#' Workplan IV.6 a-f for one measure. Call inside an R Markdown chunk with results = "asis".
#'   a. distribution plot            hist()
#'   b. stats, all tracts and years  rstatix::get_summary_stats(type = "full")
#'   c. stats by year                rstatix (by tract-year is one value per group at tract level)
#'   d. ICC                          lme4::lmer null model + performance::icc()
#'   e. trend plot, all tracts       ggplot2
#'   f. trend plot by tract          ggplot2
describe_measure <- function(df, measure, id_col, label = measure) {
  need_pkgs(c("rstatix", "lme4", "performance", "ggplot2"))
  d <- df[!is.na(df[[measure]]), c(id_col, "year", measure)]
  cat("\n\n### ", label, " (`", measure, "`)\n\n", sep = "")
  if (!nrow(d)) { cat("_No non-missing values._\n\n"); return(invisible()) }
  yrs <- range(d$year)

  # a. Simple distribution plot
  cat("**a. Distribution**\n\n")
  hist(d[[measure]], main = label, xlab = label)

  # b. Descriptive statistics across all tracts and years
  cat("\n\n**b. Summary statistics, all tracts and years**\n\n")
  cat(knitr::kable(rstatix::get_summary_stats(d, dplyr::all_of(measure), type = "full"), digits = 3), sep = "\n")

  # c. Disaggregated by year
  cat("\n\n**c. Summary statistics by year**\n\n")
  by_year <- d |>
    dplyr::group_by(year) |>
    rstatix::get_summary_stats(dplyr::all_of(measure), type = "full")
  cat(knitr::kable(by_year, digits = 3), sep = "\n")

  # d. Intraclass correlation coefficient: measure predicted only by tract
  null_model <- tryCatch(
    lme4::lmer(stats::as.formula(paste0("`", measure, "` ~ 1 + (1 | ", id_col, ")")), data = d, REML = TRUE),
    error = function(e) NULL
  )
  icc <- if (is.null(null_model)) NULL else performance::icc(null_model)
  cat("\n\n**d. Intraclass correlation (ICC), null model with tract random intercept:** ",
      if (is.null(icc) || all(is.na(unlist(icc)))) "not estimable" else
        sprintf("adjusted ICC = %.3f", icc$ICC_adjusted), "\n\n", sep = "")

  # e. Trend plot (all tracts): every tract-year as a point, line through the yearly mean
  print(ggplot2::ggplot(d, ggplot2::aes(x = year, y = .data[[measure]])) +
          ggplot2::geom_point(alpha = 0.15) +
          ggplot2::stat_summary(fun = mean, geom = "line", linewidth = 1) +
          ggplot2::stat_summary(fun = mean, geom = "point", size = 2) +
          ggplot2::scale_x_continuous(breaks = unique(d$year)) +
          ggplot2::labs(x = "Year", y = label,
                        title = stringr::str_wrap(sprintf("%s Trend, %d-%d (All %s County Tracts)", label, yrs[1], yrs[2], COUNTY_NAME), 60),
                        subtitle = "Points = tracts; line = yearly mean") +
          ggplot2::theme_classic())

  # f. Trend plot disaggregated by tract
  print(ggplot2::ggplot(d, ggplot2::aes(x = year, y = .data[[measure]],
                                        color = factor(.data[[id_col]]), group = factor(.data[[id_col]]))) +
          ggplot2::geom_line(alpha = 0.4) +
          ggplot2::geom_point(size = 0.6, alpha = 0.4) +
          ggplot2::scale_x_continuous(breaks = unique(d$year)) +
          ggplot2::labs(x = "Year", y = label, color = "Tract",
                        title = stringr::str_wrap(sprintf("%s Trend by Tract, %d-%d (%s County)", label, yrs[1], yrs[2], COUNTY_NAME), 60)) +
          ggplot2::theme_classic() +
          ggplot2::theme(legend.position = "none"))   # hundreds of tracts: a legend is unreadable
  invisible()
}
