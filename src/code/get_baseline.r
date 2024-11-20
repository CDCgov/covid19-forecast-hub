library(epipredict)

parser <- argparser::arg_parser(
  "Create a flat baseline model for covid-19 hospital admissions"
)
parser <- argparser::add_argument(
  parser, "--reference-date",
  help = "reference date in YYYY-MM-DD format"
)

args <- argparser::parse_args(parser)
reference_date <- as.Date(args$reference_date)

dow_supplied <- lubridate::wday(reference_date,
  week_start = 7,
  label = FALSE
)
if (dow_supplied != 7) {
  cli::cli_abort(message = paste0(
    "Expected `reference_date` to be a Saturday, day number 7 ",
    "of the week, given the `week_start` value of Sunday. ",
    "Got {reference_date}, which is day number ",
    "{dow_supplied} of the week."
  ))
}

desired_max_time_value <- reference_date - 7L

target_tbl <- readr::read_csv(
  "target-data/covid-hospital-admissions.csv",
  col_types = readr::cols_only(
    date = readr::col_date(format = ""),
    location = readr::col_character(),
    state = readr::col_character(),
    value = readr::col_double()
  )
)
target_start_date <- min(target_tbl$date)

target_epi_df <- target_tbl |>
  dplyr::transmute(
    geo_value = state,
    time_value = .data$date,
    weekly_count = .data$value
  ) |>
  epiprocess::as_epi_df()

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
    More than {100*overlatent_err_thresh}% of locations have excess
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

rng_seed <- as.integer((59460707 + as.numeric(reference_date)) %% 2e9)
withr::with_rng_version("4.0.0", withr::with_seed(rng_seed, {
  fcst <- epipredict::cdc_baseline_forecaster(
    target_epi_df |>
      dplyr::filter(time_value >= target_start_date) |>
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
              length(epipredict::cdc_baseline_args_list()$quantile_levels)
            ),
            quantile_levels = epipredict::cdc_baseline_args_list()$quantile_levels # nolint
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

readr::write_csv(
  preds_formatted,
  file.path(
    output_dirpath,
    paste0(as.character(reference_date), "-", "CovidHub-baseline.csv")
  )
)
