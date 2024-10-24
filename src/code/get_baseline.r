# library(readr)
# library(dplyr)
# library(tidyr)
# library(purrr)
# library(checkmate)
# library(cli)
# library(epidatr)
# library(epiprocess)
# library(lubridate)
library(epipredict)

#' Return `date` if it has the desired weekday, else the next date that does
#' @param date `Date` vector
#' @param ltwday integerish vector; of weekday code(s), following POSIXlt
#'   encoding but allowing either 0 or 7 to represent Sunday.
#' @return `Date` object
curr_or_next_date_with_ltwday <- function(date, ltwday) {
  checkmate::assert_class(date, "Date")
  checkmate::assert_integerish(ltwday, lower = 0L, upper = 7L)
  date + (ltwday - as.POSIXlt(date)$wday) %% 7L
}

#' Convert location code to abbreviation using state census data
#' @param location vector of FIPS codes
#' @return vector of state abbreviations
location_to_abbr <- function(location) {
  dictionary <-
    epipredict::state_census |>
    dplyr::mutate(fips = sprintf("%02d", fips)) |>
    dplyr::transmute(
      location = dplyr::case_match(fips, "00" ~ "US", .default = fips),
      abbr
    )
  dictionary$abbr[match(location, dictionary$location)]
}

# Prepare data
target_tbl <- readr::read_csv(
  "target-data/target-hospital-admissions.csv",
  col_types = readr::cols_only(
    date = readr::col_date(format = ""),
    location = readr::col_character(),
    location_name = readr::col_character(),
    value = readr::col_double(),
    weekly_rate = readr::col_double()
  )
)

target_epi_df <- target_tbl |>
  dplyr::transmute(
    geo_value = location_to_abbr(location),
    time_value = .data$date,
    weekly_count = .data$value
  ) |>
  epiprocess::as_epi_df()

# date settings
forecast_as_of_date <- Sys.Date()
reference_date <- curr_or_next_date_with_ltwday(forecast_as_of_date, 6L)
desired_max_time_value <- reference_date - 7L

# Validation:
excess_latency_tbl <- target_epi_df |>
  tidyr::drop_na(weekly_count) |>
  dplyr::group_by(geo_value) |>
  dplyr::summarize(
    max_time_value = max(time_value),
    .groups = "drop"
  ) |>
  dplyr::mutate(
    excess_latency =
      pmax(
        as.integer(desired_max_time_value - max_time_value) %/% 7L,
        0L
      ),
    has_excess_latency = excess_latency > 0L
  )
excess_latency_small_tbl <- excess_latency_tbl |>
  dplyr::filter(has_excess_latency)

overlatent_err_thresh <- 0.20
prop_locs_overlatent <- mean(excess_latency_tbl$has_excess_latency)

# Error handling for excess latency
if (prop_locs_overlatent > overlatent_err_thresh) {
  cli::cli_abort("
    More than {100*prop_locs_overlatent_err_thresh}% of locations have excess
    latency. The reference date is {reference_date} so we desire observations at
    least through {desired_max_time_value}. However,
    {nrow(excess_latency_small_tbl)} location{?s} had excess latency and did not
    have reporting through that date: {excess_latency_small_tbl$geo_value}.
  ")
} else if (prop_locs_overlatent > 0) {
  cli::cli_warn("
    Some locations have excess latency. The reference date is {reference_date}
    so we desire observations at least through {desired_max_time_value}.
    However, {nrow(excess_latency_small_tbl)} location{?s} had excess latency
    and did not have reporting through that date:
    {excess_latency_small_tbl$geo_value}.
  ")
}

# Prepare baseline, rng_seed for reproducibility
rng_seed <- as.integer((59460707 + as.numeric(reference_date)) %% 2e9)
withr::with_rng_version("4.0.0", withr::with_seed(rng_seed, {
  fcst <- epipredict::cdc_baseline_forecaster(
    target_epi_df |>
      dplyr::filter(time_value >= as.Date("2023-12-04")) |>
      dplyr::filter(time_value <= desired_max_time_value),
    "weekly_count",
    epipredict::cdc_baseline_args_list(aheads = 1:4, nsims = 1e5)
  )

  # advance forecast_date by a week due to data latency and 
  # create forecast for horizon -1
  preds <- fcst$predictions |>
    dplyr::mutate(
      forecast_date = reference_date,
      ahead = as.integer(.data$target_date - reference_date) %/% 7L
    ) |>
    dplyr::bind_rows(
      # Prepare -1 horizon predictions:
      target_epi_df |>
        tidyr::drop_na(weekly_count) |>
        dplyr::slice_max(time_value) |>
        dplyr::transmute(
          forecast_date = reference_date,
          target_date = reference_date - 7L,
          ahead = -1L,
          geo_value,
          .pred = weekly_count,
          # get quantiles
          .pred_distn = epipredict::dist_quantiles(
            values = purrr::map(
              weekly_count,
              rep,
              length(cdc_baseline_args_list()$quantile_levels)
            ),
            quantile_levels = cdc_baseline_args_list()$quantile_levels
          )
        )
    )
}))

# format to hub style
preds_formatted <- preds |>
  epipredict::flusight_hub_formatter(
    target = "wk inc covid hosp",
    output_type = "quantile"
  ) |>
  tidyr::drop_na(output_type_id) |>
  dplyr::arrange(target, horizon, location) |>
  dplyr::select(
    reference_date, horizon, target, target_end_date, location,
    output_type, output_type_id, value
  )

output_dirpath <- "CovidHub-baseline/"
if (!dir.exists(output_dirpath)) {
  dir.create(output_dirpath, recursive = TRUE)
}

write.csv(preds_formatted, paste0(
  output_dirpath,
  reference_date,
  "-",
  "CovidHub-baseline.csv"
))
