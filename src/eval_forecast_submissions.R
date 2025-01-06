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

# parse CLI arguments
args <- argparser::parse_args(parser)
base_hub_path <- args$base_hub_path
reference_date <- args$reference_date
models_to_exclude <- args$model_to_exclude

# generate a table of scorable quantiles
hub_table <- forecasttools::hub_to_scorable_quantiles(
  hub_path = base_hub_path
)

# rilter out excluded models
all_models <- unique(hub_table$model_id)
if (!is.null(models_to_exclude)) {
  models_to_evaluate <- setdiff(all_models, models_to_exclude)
} else {
  models_to_evaluate <- all_models
}

# get hub table output
hub_table <- hub_table |>
  dplyr::filter(model_id %in% models_to_evaluate)





# load observed data
observed_file_path <- fs::path(
  base_hub_path,
  "target-data",
  "target-hospital-admissions.csv"
)
if (!file.exists(observed_file_path)) {
  stop(paste(
    "The observation data file does not exist at:",
    observed_file_path
  ))
}
observed_data <- readr::read_csv(observed_file_path)





# create a scoringutils-ready table
scorable_table <- forecasttools::quantile_table_to_scorable(
  hubverse_quantile_table = hub_table,
  observation_table = observed_data,
  obs_value_column = "value",
  obs_location_column = "location",
  obs_date_column = "date"
)



# perform scoring
scored_results <- scoringutils::score(
  scorable_table,
  metrics = scoringutils::get_metrics(scorable_table)
)

# save the scoring results
output_path <- file.path(base_hub_path, "evaluation-results")
dir.create(output_path, showWarnings = FALSE)
scoring_output_file <- file.path(
  output_path,
  paste0(reference_date, "-scored.csv")
)
readr::write_csv(scored_results, scoring_output_file)

# plot predictions vs observed data
forecasttools::plot_pred_obs_by_forecast_date(
  scorable_table = scorable_table,
  horizons = c(0, 1, 2),
  prediction_interval_width = 0.95,
  forecast_date_col = "reference_date",
  target_date_col = "target_end_date",
  predicted_col = "predicted",
  observed_col = "observed",
  quantile_level_col = "quantile_level",
  horizon_col = "horizon",
  facet_columns = "model_id",
  x_label = "Date",
  y_label = "Target",
  y_transform = "log10"
)

cat(
  "Scoring and plotting complete. Results saved to:",
  scoring_output_file, "\n"
)
