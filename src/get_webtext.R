#' Rscript to generate texts for the visualization webpage
#' To run:
#' Rscript src/get_webtext.R --reference-date "2025-02-22" --base-hub-path "."
#'  --hub-reports-path "../covidhub-reports"

parser <- argparser::arg_parser(
  "Generate text for the webpage."
)
parser <- argparser::add_argument(
  parser,
  "--reference-date",
  type = "character",
  help = "The reference date for the forecast in YYYY-MM-DD format (ISO-8601)"
)
parser <- argparser::add_argument(
  parser,
  "--base-hub-path",
  type = "character",
  default = ".",
  help = "Path to the Covid19 forecast hub directory."
)
parser <- argparser::add_argument(
  parser,
  "--hub-reports-path",
  type = "character",
  default = "../covidhub-reports",
  help = "path to COVIDhub reports directory"
)

args <- argparser::parse_args(parser)
reference_date <- args$reference_date
base_hub_path <- args$base_hub_path
hub_reports_path <- args$hub_reports_path

weekly_data_path <- file.path(
  hub_reports_path,
  "weekly-summaries",
  reference_date
)

ensemble_us_1wk_ahead <- readr::read_csv(
  file.path(weekly_data_path, paste0(reference_date, "_covid_map_data.csv")),
  show_col_types = FALSE
) |>
  dplyr::filter(horizon == 1, location_name == "US")

target_data <- readr::read_csv(
  file.path(
    weekly_data_path,
    paste0(
      reference_date,
      "_covid_target_hospital_admissions_data.csv"
    )
  ),
  show_col_types = FALSE
)

contributing_teams <- readr::read_csv(
  file.path(
    weekly_data_path,
    paste0(reference_date, "_covid_forecasts_data.csv")
  ),
  show_col_types = FALSE
) |>
  dplyr::filter(model != "CovidHub-ensemble") |>
  dplyr::pull(model) |>
  unique()

wkly_submissions <- hubData::load_model_metadata(
  base_hub_path,
  model_ids = contributing_teams
) |>
  dplyr::distinct(.data$model_id, .data$designated_model, .keep_all = TRUE) |>
  dplyr::mutate(
    team_model_url = glue::glue(
      "[{team_name} (Model: {model_abbr})]({website_url})"
    )
  ) |>
  dplyr::select(
    model_id,
    team_abbr,
    model_abbr,
    team_model_url,
    designated_model
  )

# Generate flag for less than 80 percent of hospitals reporting
desired_weekendingdate <- as.Date(reference_date) - lubridate::dweeks(1)

exclude_territories_path <- fs::path(
  base_hub_path,
  "auxiliary-data",
  "excluded_territories",
  ext = "toml"
)
stopifnot(fs::file_exists(exclude_territories_path))
exclude_territories_toml <- RcppTOML::parseTOML(exclude_territories_path)
excluded_locations <- exclude_territories_toml$locations

percent_hosp_reporting_below80 <- forecasttools::pull_nhsn(
  api_endpoint = "https://data.cdc.gov/resource/mpgq-jmmr.json",
  columns = c("totalconfc19newadmperchosprepabove80pct"),
  start_date = "2024-11-09"
) |>
  dplyr::mutate(
    weekendingdate = as.Date(.data$weekendingdate),
    report_above_80_lgl = as.logical(
      as.numeric(.data$totalconfc19newadmperchosprepabove80pct)
    ),
    jurisdiction = dplyr::case_match(
      .data$jurisdiction,
      "USA" ~ "US",
      .default = .data$jurisdiction
    ),
    location = forecasttools::us_location_recode(
      .data$jurisdiction,
      "abbr",
      "code"
    ),
    location_name = forecasttools::us_location_recode(
      .data$jurisdiction,
      "abbr",
      "name"
    )
  ) |>
  dplyr::filter(!(.data$location %in% !!excluded_locations)) |>
  dplyr::group_by(.data$jurisdiction) |>
  dplyr::mutate(max_weekendingdate = max(.data$weekendingdate)) |>
  dplyr::ungroup()

jurisdiction_w_latency <- percent_hosp_reporting_below80 |>
  dplyr::filter(.data$max_weekendingdate < !!desired_weekendingdate)

if (nrow(jurisdiction_w_latency) > 0) {
  cli::cli_warn(
    "
    Some locations have missing reported data for the most recent week.
    The reference date is {reference_date}, we expect data at least
    through {desired_weekendingdate}. However, {nrow(jurisdiction_w_latency)}
    location{?s} did not have reporting through that date:
    {jurisdiction_w_latency$location_name}.
  "
  )
}

latest_reporting_below80 <- percent_hosp_reporting_below80 |>
  dplyr::filter(
    .data$weekendingdate == max(.data$weekendingdate),
    !.data$report_above_80_lgl
  )

reporting_rate_flag <- if (length(latest_reporting_below80$location_name) > 0) {
  location_list <- if (length(latest_reporting_below80$location_name) < 3) {
    glue::glue_collapse(latest_reporting_below80$location_name, sep = " and ")
  } else {
    glue::glue_collapse(
      latest_reporting_below80$location_name,
      sep = ", ",
      last = ", and "
    )
  }

  glue::glue(
    "The following jurisdictions had <80% of hospitals reporting for ",
    "the most recent week: {location_list}. ",
    "Lower reporting rates could impact forecast validity. Percent ",
    "of hospitals reporting is calculated based on the number of active ",
    "hospitals reporting complete data to NHSN for a given reporting week.\n\n"
  )
} else {
  ""
}

format_statistical_values <- function(median, pi_lower, pi_upper) {
  half_width <- abs(pi_upper - pi_lower) / 2
  digits <- -floor(log10(half_width))
  c(
    median = round(median, digits = digits),
    lower = round(pi_lower, digits = digits),
    upper = round(pi_upper, digits = digits)
  )
}

# generate variables used in the web text
forecast_1wk_ahead <-
  format_statistical_values(
    ensemble_us_1wk_ahead$quantile_0.5_count,
    ensemble_us_1wk_ahead$quantile_0.025_count,
    ensemble_us_1wk_ahead$quantile_0.975_count
  )

median_forecast_1wk_ahead <- forecast_1wk_ahead["median"]
lower_95ci_forecast_1wk_ahead <- forecast_1wk_ahead["lower"]
upper_95ci_forecast_1wk_ahead <- forecast_1wk_ahead["upper"]

designated <- wkly_submissions[wkly_submissions$designated_model, ]
not_designated <- wkly_submissions[!wkly_submissions$designated_model, ]
weekly_num_teams <- length(unique(designated$team_abbr))
weekly_num_models <- length(unique(designated$model_abbr))
model_incl_in_hub_ensemble <- designated$team_model_url
model_not_incl_in_hub_ensemble <- not_designated$team_model_url

first_target_data_date <- format(
  as.Date(min(target_data$week_ending_date)),
  "%B %d, %Y"
)
last_target_data_date <- format(
  as.Date(max(target_data$week_ending_date)),
  "%B %d, %Y"
)
forecast_due_date <- ensemble_us_1wk_ahead$forecast_due_date_formatted
target_end_date_1wk_ahead <- ensemble_us_1wk_ahead$target_end_date_formatted
target_end_date_2wk_ahead <- format(
  ensemble_us_1wk_ahead$target_end_date + lubridate::weeks(1),
  "%B %d, %Y"
)

last_reported_target_data <- target_data |>
  dplyr::filter(week_ending_date == max(week_ending_date), location == "US") |>
  dplyr::mutate(week_end_date_formatted = format(week_ending_date, "%B %d, %Y"))

last_reported_admissions <- round(last_reported_target_data$value, -2)

web_text <- glue::glue(
  "The CovidHub ensemble's one-week-ahead forecast predicts that the number ",
  "of new weekly laboratory-confirmed COVID-19 hospital admissions will be ",
  "approximately {median_forecast_1wk_ahead} nationally, with ",
  "{lower_95ci_forecast_1wk_ahead} to {upper_95ci_forecast_1wk_ahead} ",
  "laboratory confirmed COVID-19 hospital admissions likely reported in the ",
  "week ending {target_end_date_1wk_ahead}. This is compared to the ",
  "{last_reported_admissions} admissions reported for the week ",
  "ending {last_reported_target_data$week_end_date_formatted}, the most ",
  "recent week of reporting from U.S. hospitals.\n\n",
  "Reported and forecasted new COVID-19 hospital admissions as of ",
  "{forecast_due_date}. This week, {weekly_num_teams} modeling groups ",
  "contributed {weekly_num_models} forecasts that were eligible for inclusion ",
  "in the ensemble forecasts for at least one jurisdiction.\n\n",
  "The figure shows the number of new laboratory-confirmed COVID-19 hospital ",
  "admissions reported in the United States each week from ",
  "{first_target_data_date} through {last_target_data_date} and forecasted ",
  "new COVID-19 hospital admissions per week for this week and the next ",
  "2 weeks through {target_end_date_2wk_ahead}.\n\n",
  "{reporting_rate_flag}\n",
  "Contributing teams and models:\n\n",
  "Models included in the CovidHub ensemble:\n",
  "{paste(model_incl_in_hub_ensemble, collapse = '\n')}\n\n",
  "Models not included in the CovidHub ensemble:\n",
  "{paste(model_not_incl_in_hub_ensemble, collapse = '\n')}"
)

writeLines(
  web_text,
  file.path(weekly_data_path, paste0(reference_date, "_webtext.md"))
)
