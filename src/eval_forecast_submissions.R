#' This script evaluates all (minus provided
#' exceptions) COVID-Hub submissions for a
#' given reference date using the package
#' scoringutils. The model submissions for
#' a given reference date are grouped.
#'
#' To run:
#' Rscript eval_forecast_submissions.R
#' --reference_date 2024-11-23 --base_hub_path ../


parser <- argparser::arg_parser(
  "Command line parser for evaluating model submissions to the COVID-Hub."
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



# collect parsed CLI arguments
args <- argparser::parse_args(parser)
base_hub_path <- args$base_hub_path
reference_date <- args$reference_date

# model_output_path <-

hub_table <- forecasttools::hub_to_scorable_quantiles(base_hub_path)

# get all model names (minus exclusions) to
# consider

# function for getting all forecast files
# for a particular model directory
read_forecast_data <- function(model_dir, reference_date) {
  forecast_files <- list.files(
    model_dir,
    pattern = paste0(reference_date, ".*\\.csv"),
    full.names = TRUE
  )
  forecasts <- purrr::map_dfr(forecast_files, readr::read_csv)
  return(forecasts)
}


# function for getting target observation
# data from target-data
read_observation_data <- function(target_data_path) {
  observed <- readr::read_csv(target_data_path) |>
    dplyr::rename(target_end_date = date)
  return(observed)
}


# accumulate
read_model_csvs <- function(model_dir) {
  files <- list.files(
    file.path(
      base_path,
      model_dir
    ),
    pattern = "*.csv", full.names = TRUE
  )
  df <- purrr::map_df(files, function(x) {
    readr::read_csv(x, show_col_types = FALSE) %>%
      mutate(model = model_dir)
  })
  return(df)
}


score_hubverse <- function(forecast,
                           observed,
                           horizons = c(0, 1, 2),
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
