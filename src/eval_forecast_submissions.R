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
  "--scores_as_of",
  type = "character",
  help = "The date upon which scores were measured in YYYY-MM-DD format (ISO-8601)."
)
parser <- argparser::add_argument(
  parser,
  "--base_hub_path",
  type = "character",
  help = "Path to the COVID-19 forecast hub directory."
)
# TODO: operate in the same fashion as w/ TOML
# (1) yes, continue to exclude by locations
# (2) also, have possibility for exclusion by model

# parse CLI arguments
args <- argparser::parse_args(parser)
base_hub_path <- args$base_hub_path
scores_as_of_date <- args$scores_as_of
reference_date <- args$reference_date
models_to_exclude <- args$model_to_exclude

# generate a table of scorable quantiles
hub_table <- forecasttools::hub_to_scorable_quantiles(
  hub_path = base_hub_path,
  target_data_rel_path = fs::path("target-data", "covid-hospital-admissions.csv"),
)

# # TODO: change once TOML read exclusions
# # get hub table output
# hub_table <- hub_table |>
#   dplyr::filter(model_id %in% models_to_evaluate)
# # filter out excluded models
# all_models <- unique(hub_table$model_id)
# if (!is.null(models_to_exclude)) {
#   models_to_evaluate <- setdiff(all_models, models_to_exclude)
# } else {
#   models_to_evaluate <- all_models
# }

# perform scoring
scored_results <- scoringutils::score(
  hub_table,
  metrics = scoringutils::get_metrics(hub_table)
)

# save the scoring results (this is an
# unsummarized table)
output_path <- fs::path(base_hub_path, "eval-output")
dir.create(output_path, showWarnings = FALSE)
scoring_output_file <- file.path(
  output_path,
  paste0(scores_as_of_date, ".csv")
)
readr::write_csv(scored_results, scoring_output_file)

# https://github.com/CDCgov/pyrenew-hew/blob/main/pipelines/summarize_visualize_scores.R
# in place of pyrenew-hew, we would do
# COVID-Hub ensemble for this repository; we
# want coverage for each sub-model of the
# ensemble

# TODO: use summarizes scores; DHM advocates
# replicate [coverage plots],



# # plot predictions vs observed data
# # TODO: not state by state and date? DHM
# # suggests commenting out for now, them
# # one page per (model, state);
# # tidyr::crossing() would be used here
# model_ids <- unique(hub_table$model_id)
# model_scores <- purrr::map(
#   model_ids,
#   \(model) {
#     hub_table |>
#     dplyr::filter(model_id == !!model) |>
#     forecasttools::plot_pred_obs_by_forecast_date(
#       horizons = c(0, 1, 2),
#       prediction_interval_width = 0.95,
#       forecast_date_col = "reference_date",
#       target_date_col = "target_end_date",
#       predicted_col = "predicted",
#       observed_col = "observed",
#       quantile_level_col = "quantile_level",
#       horizon_col = "horizon",
#       x_label = "Date",
#       y_label = "Target",
#       y_transform = "log10")
# })
# forecasttools::plots_to_pdf(
#   model_scores,
#   save_path = fs::path(
#     base_hub_path,
#     "eval-output",
#     paste0(
#       scores_as_of_date,
#       "-model-scores.pdf"))) |>
#   suppressMessages()
