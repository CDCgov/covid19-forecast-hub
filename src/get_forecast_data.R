#' Generate the All Forecasts file
#' containing all COVID hub model submissions.
#'
#' This script fetches all forecast submissions
#' from the `covid19-forecast-hub` based on the
#' `reference_date`. The forecast data is then
#' pivoted to create a wide format with
#' quantile levels as columns.
#'
#' The resulting csv file contains the
#' following columns:
#' - `location_name`: full state name
#' (including "US" for the US state)
#' - `abbreviation`: state abbreviation
#' - `horizon`: forecast horizon
#' - `forecast_date`: date the forecast was generated
#' - `target_end_date`: target date for the forecast
#' - `model`: model name
#' - `quantile_*`: forecast values for various
#' quantiles (e.g., 0.025, 0.5, 0.975)
#' - `forecast_teams`: name of the team that generated the model
#' - `forecast_fullnames`: full model name
#'
#' To run:
#' Rscript src/get_forecast_data.R --reference-date 2024-12-21
#' --base-hub-path "." --hub-reports-path "path/to/covidhub-reports"
#' --horizons-to-include 0 1 2

# set up command line argument parser
parser <- argparser::arg_parser(
  "Save Forecast Data as CSV."
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
  help = "Path to the Covid19 forecast hub directory."
)
parser <- argparser::add_argument(
  parser,
  "--hub-reports-path",
  type = "character",
  help = "path to COVIDhub reports directory"
)
parser <- argparser::add_argument(
  parser,
  "--horizons-to-include",
  nargs = "Inf",
  help = "A list of horizons to include."
)

# read CLAs; get reference date and paths
args <- argparser::parse_args(parser)
ref_date <- args$reference_date
base_hub_path <- args$base_hub_path
hub_reports_path <- args$hub_reports_path
horizons_to_include <- as.integer(args$horizons_to_include)

# check for invalid horizon entries
valid_horizons <- c(-1, 0, 1, 2, 3)
invalid_horizons <- horizons_to_include[
  !sapply(
    horizons_to_include,
    function(x) x %in% valid_horizons
  )
]
if (length(invalid_horizons) > 0) {
  stop("Invalid elements: ", paste(invalid_horizons, collapse = ", "))
}

# create model metadata path
model_metadata <- hubData::load_model_metadata(
  base_hub_path,
  model_ids = NULL
)

# get `covid19-forecast-hub` content
hub_content <- hubData::connect_hub(base_hub_path)

# check if the reference date has any
# exclusions and exclude specified locations (if any)
exclude_data_path_toml <- fs::path(
  base_hub_path,
  "auxiliary-data",
  "excluded_locations.toml"
)
if (fs::file_exists(exclude_data_path_toml)) {
  exclude_data_toml <- RcppTOML::parseTOML(exclude_data_path_toml)
  if (ref_date %in% names(exclude_data_toml)) {
    excluded_locations <- exclude_data_toml[[ref_date]]
    message("Excluding locations for reference date: ", ref_date)
    current_forecasts <- hub_content |>
      dplyr::filter(reference_date == as.Date(!!ref_date)) |>
      dplyr::filter(!(location %in% excluded_locations)) |>
      dplyr::filter(target == "wk inc covid hosp") |>
      hubData::collect_hub()
  } else {
    message("No exclusions for reference date: ", ref_date)
    current_forecasts <- hub_content |>
      dplyr::filter(reference_date == as.Date(!!ref_date)) |>
      dplyr::filter(target == "wk inc covid hosp") |>
      hubData::collect_hub()
  }
} else {
  stop("TOML file not found: ", exclude_data_path_toml)
}

# get data for All Forecasts file
all_forecasts_data <- forecasttools::pivot_hubverse_quantiles_wider(
  hubverse_table = current_forecasts,
  pivot_quantiles = c(
    "quantile_0.025" = 0.025,
    "quantile_0.25" = 0.25,
    "quantile_0.5" = 0.5,
    "quantile_0.75" = 0.75,
    "quantile_0.975" = 0.975
  )
) |>
  # usually filter out horizon 3, -1
  dplyr::filter(horizon %in% !!horizons_to_include) |>
  # convert location codes to full location
  # names and to abbreviations
  dplyr::mutate(
    location_name = forecasttools::us_location_recode(
      .data$location,
      "hub",
      "name"
    ),
    abbreviation = forecasttools::us_location_recode(
      .data$location,
      "hub",
      "abbr"
    ),
    # round the quantiles to nearest integer
    # for rounded versions
    dplyr::across(
      tidyselect::starts_with("quantile_"),
      round,
      .names = "{.col}_rounded"
    ),
    forecast_due_date = as.Date(!!ref_date) - 3,
    location_sort_order = ifelse(.data$location_name == "United States", 0, 1)
  ) |>
  # long name "United States" to "US"
  dplyr::mutate(
    location_name = dplyr::case_match(
      .data$location_name,
      "United States" ~ "US",
      .default = .data$location_name
    )
  ) |>
  dplyr::arrange(.data$location_sort_order, .data$location_name) |>
  dplyr::left_join(
    dplyr::distinct(
      model_metadata,
      .data$model_id,
      .keep_all = TRUE
    ), # duplicate model_ids
    by = "model_id"
  ) |>
  dplyr::select(
    "location_name",
    "abbreviation",
    "horizon",
    forecast_date = "reference_date",
    "target_end_date",
    model = "model_id",
    "quantile_0.025",
    "quantile_0.25",
    "quantile_0.5",
    "quantile_0.75",
    "quantile_0.975",
    "quantile_0.025_rounded",
    "quantile_0.25_rounded",
    "quantile_0.5_rounded",
    "quantile_0.75_rounded",
    "quantile_0.975_rounded",
    forecast_team = "team_name",
    "forecast_due_date",
    model_full_name = "model_name"
  )

# output folder and file paths for All Forecasts
output_folder_path <- fs::path(
  hub_reports_path,
  "weekly-summaries",
  ref_date
)
output_filename <- paste0(ref_date, "_covid_forecasts_data.csv")
output_filepath <- fs::path(output_folder_path, output_filename)

# determine if the output folder exists,
# create it if not
fs::dir_create(output_folder_path)
message("Directory is ready: ", output_folder_path)

# check if the file exists, and if not,
# save to csv, else throw an error
if (!fs::file_exists(output_filepath)) {
  readr::write_csv(all_forecasts_data, output_filepath)
  message("File saved as: ", output_filepath)
} else {
  stop("File already exists: ", output_filepath)
}
