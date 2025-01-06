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

# parse cli arguments
args <- argparser::parse_args(parser)
base_hub_path <- args$base_hub_path
scores_as_of_date <- args$scores_as_of
reference_date <- args$reference_date
models_to_exclude <- args$model_to_exclude

# generate a table of scorable quantiles
hub_table <- forecasttools::hub_to_scorable_quantiles(
  hub_path = base_hub_path,
  target_data_rel_path = fs::path("target-data", "covid-hospital-admissions.csv")
)

# perform scoring
scored_results <- scoringutils::score(
  hub_table,
  metrics = scoringutils::get_metrics(hub_table)
)

# save the scoring results (unsummarized table)
output_path <- fs::path(base_hub_path, "eval-output")
base::dir.create(output_path, showWarnings = FALSE)
scoring_output_file <- fs::path(output_path, base::paste0(scores_as_of_date, ".csv"))

# check if the file exists
if (!fs::file_exists(scoring_output_file)) {
  readr::write_csv(scored_results, scoring_output_file)
  base::cat("File written to:", scoring_output_file, "\n")
} else {
  base::cat("File already exists. Skipping write:", scoring_output_file, "\n")
}

# load scores for postprocessing
quantile_scores <- scored_results

print(quantile_scores)

with_horizons <- function(df) {
  return(df |>
    dplyr::mutate(horizon = base::floor(base::as.numeric(.data$target_end_date - .data$reference_date) / 7)))
}

# define example functions for summarization and plotting
summarised_scoring_table <- function(quantile_scores,
                                     scale = "natural",
                                     baseline = "cdc_baseline",
                                     by = NULL) {
  filtered_scores <- quantile_scores |>
    dplyr::filter(scale == !!scale)

  summarised_rel <- filtered_scores |>
    scoringutils::get_pairwise_comparisons(
      baseline = baseline,
      by = by
    ) |>
    dplyr::filter(.data$compare_against == !!baseline) |>
    dplyr::select(model_id,
      dplyr::all_of(by),
      relative_wis =
        "wis_scaled_relative_skill"
    )

  summarised <- filtered_scores |>
    scoringutils::summarise_scores(by = c("model_id", by)) |>
    dplyr::select(model_id,
      dplyr::all_of(by),
      abs_wis = wis,
      mae = ae_median,
      interval_coverage_50,
      interval_coverage_90,
      interval_coverage_95
    ) |>
    dplyr::inner_join(summarised_rel,
      by = c("model_id", by)
    )
  return(summarised)
}


plot_scores_by_date <- function(scores_by_date,
                                date_column = "reference_date",
                                score_column = "relative_wis",
                                model_column = "model_id",
                                plot_title = "Scores by model over time",
                                xlabel = "Date",
                                ylabel = "Relative WIS") {
  min_score <- base::min(scores_by_date[[score_column]])
  max_score <- base::max(scores_by_date[[score_column]])
  max_overall <- base::max(c(1 / min_score, max_score))
  sym_ylim <- c(1 / max_overall, max_overall)

  score_fig <- scores_by_date |>
    ggplot2::ggplot(ggplot2::aes(
      x = .data[[date_column]],
      y = .data[[score_column]],
      color = .data[[model_column]],
      fill = .data[[model_column]]
    )) +
    ggplot2::geom_line(linewidth = 2) +
    ggplot2::geom_point(
      shape = 21,
      size = 3,
      color = "black"
    ) +
    ggplot2::labs(
      title = plot_title,
      x = xlabel,
      y = ylabel
    ) +
    ggplot2::scale_y_continuous(trans = "log10") +
    ggplot2::theme_minimal() +
    ggplot2::coord_cartesian(ylim = sym_ylim) +
    ggplot2::facet_wrap(~horizon)

  return(score_fig)
}

relative_wis_by_location <- function(summarised_scores,
                                     model_id = "CovidHub-ensemble") {
  summarised_scores <- summarised_scores |>
    dplyr::filter(.data$model_id == !!model_id)

  min_wis <- base::min(summarised_scores$relative_wis)
  max_wis <- base::max(summarised_scores$relative_wis)
  max_overall <- base::max(c(1 / min_wis, max_wis))
  sym_xlim <- c(1 / max_overall, max_overall)

  ordered_locs <- summarised_scores |>
    dplyr::filter(.data$horizon == base::min(.data$horizon)) |>
    dplyr::arrange(.data$relative_wis) |>
    dplyr::pull("location")

  fig <- summarised_scores |>
    dplyr::mutate(location = base::factor(.data$location,
      ordered = TRUE,
      levels = !!ordered_locs
    )) |>
    ggplot2::ggplot(
      ggplot2::aes(
        y = location,
        x = relative_wis,
        group = model_id
      )
    ) +
    ggplot2::geom_point(
      shape = 21,
      size = 3,
      fill = "darkblue",
      color = "black"
    ) +
    ggplot2::geom_vline(
      xintercept = 1,
      linetype = "dashed"
    ) +
    ggplot2::scale_x_continuous(trans = "log10") +
    ggplot2::coord_cartesian(xlim = sym_xlim) +
    ggplot2::theme_minimal() +
    ggplot2::facet_wrap(~horizon,
      nrow = 1
    )

  return(fig)
}

coverage_plot <- function(data,
                          coverage_level,
                          date_column = "date") {
  coverage_column <- glue::glue("interval_coverage_{100 * coverage_level}")
  return(
    ggplot2::ggplot(
      data = data,
      mapping = ggplot2::aes(
        x = .data[[date_column]],
        y = .data[[coverage_column]]
      )
    ) +
      ggplot2::geom_line(linewidth = 2) +
      ggplot2::geom_point(shape = 21, size = 3, fill = "darkgreen") +
      ggplot2::geom_hline(
        yintercept = coverage_level,
        linewidth = 1.5,
        linetype = "dashed"
      ) +
      ggplot2::facet_wrap(~horizon_name) +
      ggplot2::scale_y_continuous(label = scales::label_percent()) +
      ggplot2::scale_x_date() +
      ggplot2::coord_cartesian(ylim = c(0, 1)) +
      ggplot2::theme_minimal()
  )
}

# postprocess scores
summarised_scores <- summarised_scoring_table(
  quantile_scores,
  scale = "log",
  baseline = "CovidHub-baseline"
)

print(summarised_scores)

# save summarised scores
summary_save_path <- fs::path(output_path, "summary_scores.tsv")
readr::write_tsv(summarised_scores, summary_save_path)

# generate and save coverage plots
coverage_plots <- purrr::map(
  c(0.5, 0.9, 0.95),
  \(level) {
    coverage_plot(
      summarised_scores,
      coverage_level = level,
      date_column = "reference_date"
    )
  }
)
forecasttools::plots_to_pdf(
  coverage_plots,
  fs::path(output_path, "coverage_by_date_and_horizon.pdf"),
  width = 8,
  height = 4
)

# generate and save relative wis by date plot
rel_wis_by_date <- plot_scores_by_date(
  summarised_scores,
  date_column = "reference_date",
  score_column = "relative_wis",
  model_column = "model_id"
)
ggplot2::ggsave(
  fs::path(output_path, "relative_wis_by_date.pdf"),
  rel_wis_by_date,
  width = 10,
  height = 8
)



# generate and save relative wis by location and horizon plot
rel_wis_by_location_horizon <- relative_wis_by_location(
  summarised_scores,
  model_id = "CovidHub-ensemble"
)
ggplot2::ggsave(
  fs::path(output_path, "relative_wis_by_location_horizon.pdf"),
  rel_wis_by_location_horizon,
  height = 10,
  width = 8
)
base::cat("Scoring and plotting complete. Outputs saved to: ", output_path, "\n")




# https://github.com/CDCgov/pyrenew-hew/blob/main/pipelines/summarize_visualize_scores.R
# in place of pyrenew-hew, we would do
# COVID-Hub ensemble for this repository; we
# want coverage for each sub-model of the
# ensemble

# TODO: use summarizes scores; DHM advocates
# replicate [coverage plots],

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
