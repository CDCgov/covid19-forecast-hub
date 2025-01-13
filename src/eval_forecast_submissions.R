#' This script evaluates all (minus provided
#' exceptions) COVID-Hub submissions for a
#' given reference date using the package
#' scoringutils. The model submissions for
#' a given reference date are grouped.
#'
#' To run:
#' Rscript eval_forecast_submissions.R


get_date_specific_exclusions <- function(base_hub_path) {
  exclusions <- RcppTOML::parseTOML(fs::path("auxiliary-data",
    "excluded_locations",
    ext = "toml"
  )) |>
    tibble::enframe(
      name = "reference_date",
      value = "location"
    ) |>
    dplyr::mutate(
      reference_date = lubridate::ymd(.data$reference_date)
    ) |>
    tidyr::unnest_longer("location")

  return(exclusions)
}

get_excluded_locs <- function(base_hub_path) {
  ex_locs <- RcppTOML::parseTOML(fs::path("auxiliary-data",
    "excluded_territories",
    ext = "toml"
  ))$locations

  return(ex_locs)
}


get_hub_table <- function(base_hub_path) {
  exclusions <- get_date_specific_exclusions(base_hub_path)
  always_excluded_locs <- get_excluded_locs(base_hub_path)
  target_data_rel_path <- fs::path(
    "target-data",
    "covid-hospital-admissions.csv"
  )
  hub_table <- forecasttools::hub_to_scorable_quantiles(
    hub_path = base_hub_path,
    target_data_rel_path =
      target_data_rel_path
  ) |>
    dplyr::filter(
      .data$horizon >= 0,
      !.data$location %in% !!always_excluded_locs
    ) |>
    dplyr::anti_join(exclusions,
      by = c("reference_date", "location")
    ) |>
    dplyr::rename(model = "model_id") |>
    dplyr::mutate(location = forecasttools::us_loc_code_to_abbr(
      .data$location
    ))

  return(hub_table)
}


with_horizons <- function(df) {
  return(
    dplyr::mutate(df, horizon = floor(
      as.numeric(.data$target_end_date - .data$reference_date) / 7
    ))
  )
}


summarised_scoring_table <- function(quantile_scores,
                                     scale = "natural",
                                     baseline = "CovidHub-baseline",
                                     by = NULL) {
  filtered_scores <- quantile_scores |>
    dplyr::filter(scale == !!scale)

  summarised_rel <- filtered_scores |>
    scoringutils::get_pairwise_comparisons(
      baseline = baseline,
      by = by
    ) |>
    dplyr::filter(.data$compare_against == !!baseline) |>
    dplyr::select("model",
      dplyr::all_of(by),
      relative_wis =
        "wis_scaled_relative_skill"
    )

  summarised <- filtered_scores |>
    scoringutils::summarise_scores(by = c("model", by)) |>
    dplyr::select("model",
      dplyr::all_of(by),
      abs_wis = "wis",
      mae = "ae_median",
      "interval_coverage_50",
      "interval_coverage_80",
      "interval_coverage_90",
      "interval_coverage_95"
    ) |>
    dplyr::inner_join(summarised_rel,
      by = c("model", by)
    )
  return(summarised)
}


plot_scores_by_date <- function(scores_by_date,
                                date_column = "reference_date",
                                score_column = "relative_wis",
                                model_column = "model",
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
                                     model = "CovidHub-ensemble") {
  summarised_scores <- summarised_scores |>
    dplyr::filter(.data$model == !!model)

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
        y = .data$location,
        x = .data$relative_wis,
        group = .data$model
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
      ggplot2::facet_wrap(c("horizon")) +
      ggplot2::scale_y_continuous(label = scales::label_percent()) +
      ggplot2::scale_x_date() +
      ggplot2::coord_cartesian(ylim = c(0, 1)) +
      ggplot2::theme_minimal()
  )
}

interval_coverage_80 <- purrr::partial(scoringutils::interval_coverage,
  interval_range = 80
)
interval_coverage_95 <- purrr::partial(scoringutils::interval_coverage,
  interval_range = 95
)


evaluate_and_save <- function(base_hub_path,
                              scores_as_of_date) {
  base_hub_path <- fs::path(base_hub_path)
  hub_table <- get_hub_table(base_hub_path)
  scored_results <- hub_table |>
    scoringutils::score(metrics = c(
      scoringutils::get_metrics(hub_table),
      interval_coverage_80 = interval_coverage_80,
      interval_coverage_95 = interval_coverage_95
    ))

  output_path <- fs::path(base_hub_path, "eval-output")
  fs::dir_create(output_path)
  scoring_output_file <- fs::path(
    output_path,
    glue::glue("{scores_as_of_date}.csv")
  )

  readr::write_csv(scored_results, scoring_output_file)
  message("Raw scores written to ", scoring_output_file)

  summarised_scores <- summarised_scoring_table(
    scored_results,
    scale = "log",
    baseline = "CovidHub-baseline"
  )

  summarised_by_ref_date_horizon <- summarised_scoring_table(
    scored_results,
    scale = "log",
    baseline = "CovidHub-baseline",
    by = c("horizon", "reference_date", "target_end_date")
  )

  summarised_by_loc_date_horizon <- summarised_scoring_table(
    scored_results,
    scale = "log",
    baseline = "CovidHub-baseline",
    by = c("horizon", "location", "target_end_date")
  )

  summarised_by_location_horizon <- summarised_scoring_table(
    scored_results,
    scale = "log",
    baseline = "CovidHub-baseline",
    by = c("horizon", "location")
  )

  summarised_by_loc_hor_date <- summarised_scoring_table(
    scored_results,
    scale = "log",
    baseline = "CovidHub-baseline",
    by = c("horizon", "location", "target_end_date", "reference_date")
  )

  summary_save_path <- fs::path(output_path, "summary_scores.tsv")
  readr::write_tsv(summarised_scores, summary_save_path)

  coverage_plots <- purrr::map(
    c(0.5, 0.8, 0.9, 0.95),
    \(level) {
      coverage_plot(
        summarised_by_ref_date_horizon |>
          dplyr::filter(model == "CovidHub-ensemble"),
        coverage_level = level,
        date_column = "target_end_date"
      )
    }
  )
  forecasttools::plots_to_pdf(
    coverage_plots,
    fs::path(output_path, glue::glue(
      "{scores_as_of_date}_coverage_by_date_and_horizon.pdf"
    )),
    width = 8,
    height = 4
  )

  rel_wis_by_date <- plot_scores_by_date(
    summarised_by_ref_date_horizon,
    date_column = "reference_date",
    score_column = "relative_wis",
    model_column = "model"
  )
  ggplot2::ggsave(
    fs::path(output_path, glue::glue(
      "{scores_as_of_date}_relative_wis_by_date.pdf"
    )),
    rel_wis_by_date,
    width = 10,
    height = 8
  )

  rel_wis_by_location_horizon <- relative_wis_by_location(
    summarised_by_location_horizon,
    model = "CovidHub-ensemble"
  )
  ggplot2::ggsave(
    fs::path(output_path, glue::glue(
      "{scores_as_of_date}_relative_wis_by_location_horizon.pdf"
    )),
    rel_wis_by_location_horizon,
    height = 10,
    width = 8
  )

  models <- dplyr::distinct(
    summarised_by_loc_hor_date, model
  ) |> dplyr::pull(model)
  states <- dplyr::distinct(
    summarised_by_loc_hor_date, location
  ) |> dplyr::pull(location)
  model_state_combinations <- tidyr::crossing(models, states)

  ###########################################

  # # full model coverage across states
  # # (date and horizon)
  # coverage_plots_ref_date_hor <- purrr::map(
  #   model_state_combinations$models,
  #   \(model) {
  #     filtered_data <- summarised_by_ref_date_horizon |>
  #       dplyr::filter(model == !!model)
  #     if (nrow(filtered_data) == 0) {
  #       warning(
  #         glue::glue("No data available for Model: {model}.")
  #       )
  #       return(NULL)
  #     }
  #     purrr::map(
  #       c(0.5, 0.8, 0.9, 0.95),
  #       \(level) {
  #         (coverage_plot(
  #           filtered_data,
  #           coverage_level = level,
  #           date_column = "target_end_date"
  #         ) +
  #           ggplot2::ggtitle(
  #             glue::glue("Model: {model} (as of: {scores_as_of_date})")
  #           ))
  #       }
  #     )
  #   }
  # )
  # coverage_plots_ref_date_hor <- purrr::compact(
  #   coverage_plots_ref_date_hor
  # ) |> purrr::flatten()
  # if (length(coverage_plots_ref_date_hor) > 0) {
  #   forecasttools::plots_to_pdf(
  #     coverage_plots_ref_date_hor,
  #     fs::path(output_path, glue::glue(
  #       "{scores_as_of_date}_model_coverage_by_date.pdf"
  #     )),
  #     width = 8,
  #     height = 4
  #   )
  # } else {
  #   message("No coverage plots to save.")
  # }

  ###########################################

  # # full model coverage for each state
  # # (date and horizon)
  # coverage_plots_by_state_model <- purrr::map2(
  #   model_state_combinations$models,
  #   model_state_combinations$states,
  #   \(model, state) {
  #     filtered_data <- summarised_by_loc_date_horizon |>
  #       dplyr::filter(model == !!model, location == !!state)
  #     if (nrow(filtered_data) == 0) {
  #       warning(
  #         glue::glue("No data available for Model: {model}, State: {state}")
  #       )
  #       return(NULL)
  #     }
  #     purrr::map(
  #       c(0.5, 0.8, 0.9, 0.95),
  #       \(level) {
  #         (coverage_plot(
  #           filtered_data,
  #           coverage_level = level,
  #           date_column = "target_end_date"
  #         ) +
  #           ggplot2::ggtitle(
  #             glue::glue(
  #               "Model: {model} (as of: {scores_as_of_date})\nState: {state}"
  #             )
  #           ))
  #       }
  #     )
  #   }
  # )
  # coverage_plots_by_state_model <- purrr::compact(
  #   coverage_plots_by_state_model
  # ) |> purrr::flatten()
  # if (length(coverage_plots_by_state_model) > 0) {
  #   forecasttools::plots_to_pdf(
  #     coverage_plots_by_state_model,
  #     fs::path(output_path, glue::glue(
  #       "{scores_as_of_date}_model_coverage_by_state.pdf"
  #     )),
  #     width = 8,
  #     height = 4
  #   )
  # } else {
  #   message("No coverage plots to save.")
  # }

  # # full model rel. WIS by horizon and date
  # # for each state
  # rel_wis_date_plots <- purrr::map2(
  #   model_state_combinations$models,
  #   model_state_combinations$states,
  #   \(model, state) {
  #     filtered_data <- summarised_by_loc_hor_date |>
  #       dplyr::filter(model == !!model, location == !!state)
  #     if (nrow(filtered_data) == 0) {
  #       warning(
  #         glue::glue(
  #           "No data available for Model: {model}, State: {state}"
  #         )
  #       )
  #       return(NULL)
  #     }

  #     (plot_scores_by_date(
  #       filtered_data,
  #       date_column = "reference_date",
  #       score_column = "relative_wis",
  #       model_column = "model"
  #     ) +
  #       ggplot2::ggtitle(
  #         glue::glue(
  #           "Rel. WIS Across Dates (as of: {scores_as_of_date})\nModel: {model} | State: {state}"
  #         )
  #       ))
  #   }
  # )
  # rel_wis_date_plots <- purrr::compact(rel_wis_date_plots)
  # if (length(rel_wis_date_plots) > 0) {
  #   forecasttools::plots_to_pdf(
  #     rel_wis_date_plots,
  #     fs::path(output_path, glue::glue(
  #       "{scores_as_of_date}_relative_wis_by_model_state_date.pdf"
  #     )),
  #     width = 8,
  #     height = 4
  #   )
  # } else {
  #   message("No relative WIS by date plots to save.")
  # }

  ###########################################

  # full model rel. WIS (to ensemble) by 
  # horizon and date for each state 
  rel_wis_ens_date_plots <- purrr::map2(
    model_state_combinations$models,
    model_state_combinations$states,
    \(model, state) {
      filtered_data <- summarised_by_loc_hor_date |>
        dplyr::filter((model == !!model | model == "CovidHub-ensemble"), location == !!state)
      if (nrow(filtered_data) == 0) {
        warning(
          glue::glue(
            "No data available for Model: {model}, State: {state}"
          )
        )
        return(NULL)
      }
      (plot_scores_by_date(
        filtered_data,
        date_column = "reference_date",
        score_column = "relative_wis",
        model_column = "model"
      ) +
        ggplot2::ggtitle(
          glue::glue(
            "Rel. WIS To Ens. Across Dates (as of: {scores_as_of_date})\nModel: {model} | State: {state}"
          )
        ))
    }
  )
  rel_wis_ens_date_plots <- purrr::compact(rel_wis_ens_date_plots)
  if (length(rel_wis_ens_date_plots) > 0) {
    forecasttools::plots_to_pdf(
      rel_wis_ens_date_plots,
      fs::path(output_path, glue::glue(
        "{scores_as_of_date}_relative_wis_to_ens_by_model_state_date.pdf"
      )),
      width = 8,
      height = 4
    )
  } else {
    message("No relative WIS by date plots to save.")
  }

  ###########################################

  # # relative WIS w/ baseline and ensemble only
  # rel_wis_by_date_ens_base <- plot_scores_by_date(
  #   summarised_by_ref_date_horizon |>
  #     dplyr::filter(
  #       model == "CovidHub-ensemble" | model == "CovidHub-baseline"
  #     ),
  #   date_column = "reference_date",
  #   score_column = "relative_wis",
  #   model_column = "model"
  # )
  # ggplot2::ggsave(
  #   fs::path(output_path, glue::glue(
  #     "{scores_as_of_date}_relative_wis_by_date_ens_and_base.pdf"
  #   )),
  #   rel_wis_by_date_ens_base,
  #   width = 10,
  #   height = 8
  # )

  ###########################################

  # # relative WIS w/ baseline and ensemble,
  # # and also two best (by mean rel. WIS) models
  # baseline_data_length <- summarised_by_ref_date_horizon |>
  #   dplyr::filter(model == "CovidHub-baseline") |>
  #   dplyr::summarise(data_length = sum(!is.na(relative_wis))) |>
  #   dplyr::pull(data_length)
  # valid_models <- summarised_by_ref_date_horizon |>
  #   dplyr::group_by(model) |>
  #   dplyr::summarise(data_length = sum(!is.na(relative_wis))) |>
  #   dplyr::filter(data_length == baseline_data_length) |>
  #   dplyr::pull(model)
  # best_models <- summarised_by_ref_date_horizon |>
  #   dplyr::filter(
  #     model %in% valid_models & !model %in% c(
  #       "CovidHub-ensemble", "CovidHub-baseline"
  #     )
  #   ) |>
  #   dplyr::group_by(model) |>
  #   dplyr::summarise(mean_relative_wis = mean(
  #     relative_wis,
  #     na.rm = TRUE
  #   )) |>
  #   dplyr::arrange(mean_relative_wis) |>
  #   dplyr::slice_head(n = 2) |>
  #   dplyr::pull(model)
  # models_to_include <- c(
  #   best_models, "CovidHub-ensemble", "CovidHub-baseline"
  # )
  # filtered_models <- summarised_by_ref_date_horizon |>
  #   dplyr::filter(model %in% models_to_include)
  # rel_wis_by_date_ens_base_best <- plot_scores_by_date(
  #   filtered_models,
  #   date_column = "reference_date",
  #   score_column = "relative_wis",
  #   model_column = "model"
  # )
  # ggplot2::ggsave(
  #   fs::path(output_path, glue::glue(
  #     "{scores_as_of_date}_relative_wis_by_date_ens_base_and_two_best.pdf"
  #   )),
  #   rel_wis_by_date_ens_base_best,
  #   width = 10,
  #   height = 8
  # )

  ###########################################

  # # full model rel. WIS by horizon across states
  # rel_wis_horizon_plots <- purrr::map(
  #   models,
  #   \(model) {
  #     filtered_data <- summarised_by_location_horizon |>
  #       dplyr::filter(model == !!model)

  #     if (nrow(filtered_data) == 0) {
  #       warning(glue::glue("No data available for Model: {model}"))
  #       return(NULL)
  #     }

  #     (relative_wis_by_location(
  #       filtered_data,
  #       model = model
  #     ) +
  #       ggplot2::ggtitle(
  #         glue::glue(
  #           "Rel. WIS by Horizon (as of: {scores_as_of_date})\nModel: {model}"
  #         )
  #       ))
  #   }
  # )
  # rel_wis_horizon_plots <- purrr::compact(rel_wis_horizon_plots)
  # if (length(rel_wis_horizon_plots) > 0) {
  #   forecasttools::plots_to_pdf(
  #     rel_wis_horizon_plots,
  #     fs::path(output_path, glue::glue(
  #       "{scores_as_of_date}_relative_wis_by_model_horizon.pdf"
  #     )),
  #     width = 8,
  #     height = 7
  #   )
  # } else {
  #   message("No relative WIS by horizon plots to save.")
  # }

  message(paste0(
    "Scoring and plotting complete. ",
    "Outputs saved to "
  ), output_path)
}


parser <-
  argparser::arg_parser(paste0(
    "Evaluate forecasts submitted ",
    "to the COVID-19 Forecast Hub"
  )) |>
  argparser::add_argument(
    "--scores-as-of",
    type = "character",
    default = lubridate::today(),
    help = "Date of the scoring run in YYYY-MM-DD format."
  ) |>
  argparser::add_argument(
    "--base-hub-path",
    type = "character",
    default = ".",
    help = "Path to the Hub root directory."
  )

args <- argparser::parse_args(parser)
base_hub_path <- args$base_hub_path
scores_as_of_date <- args$scores_as_of
evaluate_and_save(
  args$base_hub_path,
  args$scores_as_of
)
