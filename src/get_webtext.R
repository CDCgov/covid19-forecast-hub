#' Rscript to generate texts for the visualization webpage
#' To run:
#' Rscript src/get_webtext.R --reference_date "2024-12-28" --base_hub_path "."

parser <- argparser::arg_parser(
  "Generate text for the webpage."
)
parser <- argparser::add_argument(
  parser,
  "--reference_date",
  type = "character",
  help = "The reference date for the forecast in YYYY-MM-DD format (ISO-8601)"
)
parser <- argparser::add_argument(
  parser,
  "--base_hub_path",
  type = "character",
  help = "Path to the Covid19 forecast hub directory."
)
parser <- argparser::add_argument(
  parser,
  "--hub_reports_path",
  type = "character",
  help = "path to COVIDhub reports directory"
)

args <- argparser::parse_args(parser)
reference_date <- args$reference_date
base_hub_path <- args$base_hub_path
hub_reports_path <- args$hub_reports_path

weekly_data_path <- file.path(
  hub_reports_path, "weekly-summaries", reference_date
)

ensemble_us_2wk_ahead <- readr::read_csv(
  file.path(weekly_data_path, paste0(reference_date, "_covid_map_data.csv")),
  show_col_types = FALSE
) |>
  dplyr::filter(horizon == 2, location_name == "US")

target_data <- readr::read_csv(
  file.path(weekly_data_path, paste0(
    reference_date, "_covid_target_hospital_admissions_data.csv"
  )),
  show_col_types = FALSE
)

contributing_teams <- readr::read_csv(
  file.path(base_hub_path, "auxiliary-data", "weekly-model-submissions", paste0(
    reference_date, "-models-submitted-to-hub.csv"
  )),
  show_col_types = FALSE
) |>
  dplyr::filter(Designated_Model)

weekly_submissions <- hubData::load_model_metadata(
  base_hub_path,
  model_ids = contributing_teams$Model
) |>
  dplyr::distinct(.data$model_id, .data$designated_model, .keep_all = TRUE) |>
  dplyr::mutate(team_model_url = glue::glue(
    "[{team_name} (Model: {model_abbr})]({website_url})"
  )) |>
  dplyr::select(model_id, team_abbr, model_abbr, team_model_url)

# Generate flag for less than 80 percent of hospitals reporting
desired_weekendingdate <- as.Date(reference_date) - lubridate::dweeks(1)
percent_hosp_reporting_below80 <- forecasttools::pull_nhsn(
  api_endpoint = "https://data.cdc.gov/resource/mpgq-jmmr.json",
  columns = c("totalconfc19newadmperchosprepabove80pct"),
  start_date = "2024-11-09"
) |>
  dplyr::mutate(
    weekendingdate = as.Date(weekendingdate),
    report_above_80_lgl = as.logical(
      as.numeric(totalconfc19newadmperchosprepabove80pct)
    )
  ) |>
  dplyr::group_by(jurisdiction) |>
  dplyr::mutate(max_weekendingdate = max(weekendingdate)) |>
  dplyr::ungroup()

jurisdiction_w_latency <- percent_hosp_reporting_below80 |>
  dplyr::filter(max_weekendingdate < desired_weekendingdate)

if (nrow(jurisdiction_w_latency) > 0) {
  cli::cli_warn("
    Some locations have missing reported data for the most recent week.
    The reference date is {reference_date}, we expect data at least
    through {desired_weekendingdate}. However, {nrow(jurisdiction_w_latency)}
    location{?s} did not have reporting through that date:
    {jurisdiction_w_latency$jurisdiction}.
  ")
}

latest_reporting_below80 <- percent_hosp_reporting_below80 |>
  dplyr::filter(
    weekendingdate == max(weekendingdate),
    !report_above_80_lgl
  )

reporting_rate_flag <- if (
  length(latest_reporting_below80$jurisdiction) > 0
) {
  glue::glue(
    "The following jurisdictions had <80% of hospitals reporting for ",
    "the most recent week: ",
    "{paste(latest_reporting_below80$jurisdiction, collapse = ', ')}. ",
    "Lower reporting rates could impact forecast validity. Percent ",
    "of hospitals reporting is calculated based on the number of active ",
    "hospitals reporting complete data to NHSN for a given reporting week.\n\n"
  )
} else {
  ""
}

# generate variables used in the web text
median_forecast_2wk_ahead <- signif(ensemble_us_2wk_ahead$quantile_0.5_count, 2)
lower_95ci_forecast_2wk_ahead <- signif(
  ensemble_us_2wk_ahead$quantile_0.025_count, 2
)
upper_95ci_forecast_2wk_ahead <- signif(
  ensemble_us_2wk_ahead$quantile_0.975_count, 2
)
weekly_num_teams <- length(unique(weekly_submissions$team_abbr))
weekly_num_models <- length(unique(weekly_submissions$model_abbr))
first_target_data_date <- format(
  as.Date(min(target_data$week_ending_date)), "%B %d, %Y"
)
last_target_data_date <- format(
  as.Date(max(target_data$week_ending_date)), "%B %d, %Y"
)
forecast_due_date <- ensemble_us_2wk_ahead$forecast_due_date_formatted
target_end_date_2wk_ahead <- ensemble_us_2wk_ahead$target_end_date_formatted

web_text <- glue::glue(
  "This week's ensemble predicts that the number of new weekly laboratory ",
  "confirmed COVID-19 hospital admissions will be approximately ",
  "{median_forecast_2wk_ahead} nationally, with ",
  "{lower_95ci_forecast_2wk_ahead} to {upper_95ci_forecast_2wk_ahead} ",
  "laboratory confirmed COVID-19 hospital admissions likely reported in the ",
  "week ending {target_end_date_2wk_ahead}.\n\n",
  "Reported and forecasted new COVID-19 hospital admissions as of ",
  "{forecast_due_date}. This week, {weekly_num_teams} modeling groups ",
  "contributed {weekly_num_models} forecasts that were eligible for inclusion ",
  "in the ensemble forecasts for at least one jurisdiction.\n\n",
  "The figure shows the number of new laboratory-confirmed COVID-19 hospital ",
  "admissions reported in the United States each week from ",
  "{first_target_data_date} through {last_target_data_date} and forecasted ",
  "new COVID-19 hospital admissions per week for this week and the next ",
  "2 weeks through {target_end_date_2wk_ahead}.\n\n",
  "{reporting_rate_flag}",
  "Contributing teams and models:\n",
  "{paste(weekly_submissions$team_model_url, collapse = '\n')}"
)

writeLines(
  web_text, file.path(weekly_data_path, paste0(reference_date, "_webtext.md"))
)
