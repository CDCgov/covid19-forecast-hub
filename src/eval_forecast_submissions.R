#' This script evaluates all COVID-Hub
#' submissions for a given reference date
#' using the package scoringutils.
#'
#' To run:
#' Rscript eval_forecast_submissions --target_data TRUE \
#'   --reference_date 2024-11-23 --base_hub_path ../


parser <- argparser::arg_parser(
  "Command line parser for evaluating submissions to the COVID-Hub."
)
parser <- argparser::add_argument(
  parser,
  "--reference_date",
  type = "character",
  help = "The reference date for the forecast in YYYY-MM-DD format (ISO-8601)."
)
parser <- argparser::add_argument(
  parser,
  "--base_hub_path",
  type = "character",
  help = "Path to the COVID-19 forecast hub directory."
)
parser <- argparser::add_argument(
  parser,
  "--model_to_exclude",
  nargs = "Inf",
  help = "Which models to exclude from the evaluation of submissions."
)

score_hubverse <- function(forecast,
                           observed,
                           horizons = c(0, 1),
                           transform = scoringutils::log_shift,
                           append_transformed = FALSE,
                           offset = 1,
                           observed_value_column = "value",
                           observed_location_column = "location",
                           observed_date_column = "reference_date",
                           ...) {
  obs <- observed |>
    dplyr::select(
      location = .data[[observed_location_column]],
      target_end_date = .data[[observed_date_column]],
      observed = .data[[observed_value_column]]
    )
  to_score <- forecast |>
    dplyr::filter(.data$horizon %in% !!horizons) |>
    dplyr::inner_join(obs,
      by = c(
        "location",
        "target_end_date"
      )
    ) |>
    scoringutils::as_forecast_quantile(
      predicted = "value",
      observed = "observed",
      quantile_level = "output_type_id"
    ) |>
    scoringutils::transform_forecasts(
      fun = transform,
      append = append_transformed,
      offset = offset,
      ...
    )
  interval_coverage_95 <- purrr::partial(
    scoringutils::interval_coverage,
    interval_range = 95
  )
  scored <- to_score |>
    scoringutils::score(
      metrics = c(
        scoringutils::get_metrics(to_score),
        interval_coverage_95 = interval_coverage_95
      )
    )
  return(scored)
}
