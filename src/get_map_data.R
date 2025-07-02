#' Generate the Map data file containing ensemble
#' forecast data.
#'
#' This script loads the latest ensemble
#' forecast data from the `CovidHub-ensemble`
#' folder and processes it into the required
#' format. The resulting CSV file contains forecast
#' values for all regions (including US, DC,
#' and Puerto Rico), for various forecast
#' horizons, and quantiles (0.025, 0.5, and 0.975).
#'
#' The ensemble data is expected to contain
#' the following columns:
#' - `reference_date`: the date of the forecast
#' - `location`: state abbreviation
#' - `horizon`: forecast horizon
#' - `target`: forecast target (e.g., "wk inc
#' covid hosp")
#' - `target_end_date`: the forecast target date
#' - `output_type`: type of output (e.g., "quantile")
#' - `output_type_id`: quantile value (e.g.,
#' 0.025, 0.5, 0.975)
#' - `value`: forecast value
#'
#' The resulting `map.csv` file will have the
#' following columns:
#' - `location_name`: full state name (
#' including "US" for the US state)
#' - `quantile_*`: the quantile forecast values
#' (rounded to two decimal places)
#' - `horizon`: forecast horizon
#' - `target`: forecast target (e.g., "7 day
#' ahead inc hosp")
#' - `target_end_date`: target date for the
#' forecast (Ex: 2024-11-30)
#' - `reference_date`: date that the forecast
#' was generated (Ex: 2024-11-23)
#' - `target_end_date_formatted`: target date
#' for the forecast, prettily re-formatted as
#' a string (Ex: "November 30, 2024")
#' - `reference_date_formatted`: date that the
#' forecast was generated, prettily re-formatted
#' as a string (Ex: "November 23, 2024")
#'
#' To run:
#' Rscript get_map_data.R --reference-date 2024-12-21
#' --base-hub-path ../ --horizons-to-include 0 1 2

# set up command line argument parser
parser <- argparser::arg_parser(
  "Save Map Data as CSV."
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

# load the latest ensemble data from the
# model-output folder
ensemble_folder <- file.path(
  base_hub_path,
  "model-output",
  "CovidHub-ensemble"
)
ensemble_file_current <- file.path(
  ensemble_folder,
  paste0(ref_date, "-CovidHub-ensemble.csv")
)
if (file.exists(ensemble_file_current)) {
  ensemble_file <- ensemble_file_current
} else {
  stop(
    "Ensemble file for reference date ",
    ref_date,
    " not found in the directory: ",
    ensemble_folder
  )
}
ensemble_data <- readr::read_csv(ensemble_file)
required_columns <- c(
  "reference_date",
  "target_end_date",
  "value",
  "location"
)
missing_columns <- setdiff(
  required_columns,
  colnames(ensemble_data)
)
if (length(missing_columns) > 0) {
  stop(
    paste(
      "Missing columns in ensemble data:",
      paste(missing_columns, collapse = ", ")
    )
  )
}

# population data, add later to forecasttools
pop_data_path <- file.path(
  base_hub_path,
  "auxiliary-data",
  "locations_with_2023_census_pop.csv"
)
pop_data <- readr::read_csv(pop_data_path)
pop_required_columns <- c("abbreviation", "population")
missing_pop_columns <- setdiff(
  pop_required_columns,
  colnames(pop_data)
)
if (length(missing_pop_columns) > 0) {
  stop(
    paste(
      "Missing columns in population data:",
      paste(missing_pop_columns, collapse = ", ")
    )
  )
}

# check if the reference date has any
# exclusions and exclude specified locations if any
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
  } else {
    excluded_locations <- character(0)
    message("No exclusion for reference date: ", ref_date)
  }
} else {
  stop("TOML file not found: ", exclude_data_path_toml)
}


# save ensemble name (using value suggested by MB)
model_name <- "CovidHub-ensemble"

# process ensemble data into the required
# format for Map file
map_data <- forecasttools::pivot_hubverse_quantiles_wider(
  hubverse_table = ensemble_data,
  pivot_quantiles = c(
    "quantile_0.025" = 0.025,
    "quantile_0.25" = 0.25,
    "quantile_0.5" = 0.5,
    "quantile_0.75" = 0.75,
    "quantile_0.975" = 0.975
  )
) |>
  # usually filter out horizon 3, -1
  dplyr::filter(.data$horizon %in% !!horizons_to_include) |>
  # filter out excluded locations if the
  # ref date is the first week in season
  dplyr::filter(!(.data$location %in% !!excluded_locations)) |>
  dplyr::mutate(
    reference_date = as.Date(.data$reference_date),
    target_end_date = as.Date(.data$target_end_date),
    model = !!model_name
  ) |>
  # convert location column codes to full
  # location names
  dplyr::mutate(
    location = forecasttools::us_location_recode(
      .data$location,
      "hub",
      "name"
    )
  ) |>
  # long name "United States" to "US"
  dplyr::mutate(
    location = dplyr::case_match(
      .data$location,
      "United States" ~ "US",
      .default = .data$location
    ),
    # sort locations alphabetically, except
    # for US
    location_sort_order = ifelse(.data$location == "US", 0, 1)
  ) |>
  dplyr::arrange(.data$location_sort_order, .data$location) |>
  dplyr::left_join(
    pop_data,
    by = c("location" = "location_name")
  ) |>
  dplyr::mutate(
    population = as.numeric(.data$population),
    quantile_0.025_per100k = .data$quantile_0.025 / .data$population * 100000,
    quantile_0.5_per100k = .data$quantile_0.5 / .data$population * 100000,
    quantile_0.975_per100k = .data$quantile_0.975 / .data$population * 100000,
    quantile_0.025_count = .data$quantile_0.025,
    quantile_0.5_count = .data$quantile_0.5,
    quantile_0.975_count = .data$quantile_0.975,
    quantile_0.025_per100k_rounded = round(.data$quantile_0.025_per100k, 2),
    quantile_0.5_per100k_rounded = round(.data$quantile_0.5_per100k, 2),
    quantile_0.975_per100k_rounded = round(.data$quantile_0.975_per100k, 2),
    quantile_0.025_count_rounded = round(.data$quantile_0.025_count),
    quantile_0.5_count_rounded = round(.data$quantile_0.5_count),
    quantile_0.975_count_rounded = round(.data$quantile_0.975_count),
    target_end_date_formatted = format(.data$target_end_date, "%B %d, %Y"),
    reference_date_formatted = format(.data$reference_date, "%B %d, %Y"),
    forecast_due_date = as.Date(!!ref_date) - 3,
    forecast_due_date_formatted = format(.data$forecast_due_date, "%B %d, %Y"),
  ) |>
  dplyr::select(
    location_name = "location",
    "horizon",
    "quantile_0.025_per100k",
    "quantile_0.5_per100k",
    "quantile_0.975_per100k",
    "quantile_0.025_count",
    "quantile_0.5_count",
    "quantile_0.975_count",
    "quantile_0.025_per100k_rounded",
    "quantile_0.5_per100k_rounded",
    "quantile_0.975_per100k_rounded",
    "quantile_0.025_count_rounded",
    "quantile_0.5_count_rounded",
    "quantile_0.975_count_rounded",
    "target",
    "target_end_date",
    "reference_date",
    "forecast_due_date",
    "target_end_date_formatted",
    "forecast_due_date_formatted",
    "reference_date_formatted",
    "model",
  )

output_folder_path <- fs::path(
  hub_reports_path,
  "weekly-summaries",
  ref_date
)
output_filename <- paste0(ref_date, "_covid_map_data")
output_filepath <- fs::path(
  output_folder_path,
  output_filename,
  ext = "csv"
)

# determine if the output folder exists,
# create it if not
fs::dir_create(output_folder_path)
message("Directory is ready: ", output_folder_path)

# check if the file exists, and if not,
# save to csv, else throw an error
if (!fs::file_exists(output_filepath)) {
  readr::write_csv(map_data, output_filepath)
  message("File saved as: ", output_filepath)
} else {
  stop("File already exists: ", output_filepath)
}
