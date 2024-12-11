#' Generate the Map file containing ensemble
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
#' Rscript gen_map_data.R --reference_date 2024-11-23
#' --base_hub_path ../../




# set up command line argument parser
parser <- argparse::ArgumentParser(
  description = "Save Truth Data as CSV."
)
parser$add_argument(
  "--reference_date",
  type = "character",
  help = "The reference date for the forecast in YYYY-MM-DD format (ISO-8601)"
)
parser$add_argument(
  "--base_hub_path",
  type = "character",
  help = "Path to the Covid19 forecast hub directory."
)

# read CLAs; get reference date and paths
args <- parser$parse_args()
ref_date <- args$reference_date
base_hub_path <- args$base_hub_path

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
  "target-data",
  "locations.csv"
)
pop_data <- readr::read_csv(pop_data_path)
pop_required_columns <- c("abbreviation", "population")
missing_pop_columns <- setdiff(
  pop_required_columns, colnames(pop_data)
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
map_data <- ensemble_data |>
  # filter out horizon 3 columns at behest
  # of Inform+Flu Division
  dplyr::filter(horizon != 3) |>
  # filter out excluded locations if the
  # ref date is the first week in season
  dplyr::filter(!(location %in% excluded_locations)) |>
  dplyr::mutate(
    reference_date = as.Date(reference_date),
    target_end_date = as.Date(target_end_date),
    value = as.numeric(value),
    model = model_name
  ) |>
  # convert location column codes to full
  # location names
  dplyr::mutate(
    location = forecasttools::location_lookup(
      location,
      location_input_format = "hub",
      location_output_format = "long_name"
    )
  ) |>
  # long name "United States" to "US"
  dplyr::mutate(
    location = dplyr::if_else(
      location == "United States",
      "US",
      location
    )
  ) |>
  # add population data for later calculations
  dplyr::left_join(
    pop_data,
    by = c("location" = "location_name")
  ) |>
  # add quantile columns for per-100k rates
  # and rounded values
  dplyr::mutate(
    quantile_0.025_per100k = value / as.numeric(population) * 100000,
    quantile_0.5_per100k = value / as.numeric(population) * 100000,
    quantile_0.975_per100k = value / as.numeric(population) * 100000,
    quantile_0.025_count = value,
    quantile_0.5_count = value,
    quantile_0.975_count = value,
    quantile_0.025_per100k_rounded = round(quantile_0.025_per100k, 2),
    quantile_0.5_per100k_rounded = round(quantile_0.5_per100k, 2),
    quantile_0.975_per100k_rounded = round(quantile_0.975_per100k, 2),
    quantile_0.025_count_rounded = round(quantile_0.025_count),
    quantile_0.5_count_rounded = round(quantile_0.5_count),
    quantile_0.975_count_rounded = round(quantile_0.975_count),
    target_end_date_formatted = format(target_end_date, "%B %d, %Y"),
    reference_date_formatted = format(reference_date, "%B %d, %Y")
  ) |>
  dplyr::select(
    location_name = location,
    model,
    quantile_0.025_per100k,
    quantile_0.5_per100k,
    quantile_0.975_per100k,
    quantile_0.025_count,
    quantile_0.5_count,
    quantile_0.975_count,
    quantile_0.025_per100k_rounded,
    quantile_0.5_per100k_rounded,
    quantile_0.975_per100k_rounded,
    quantile_0.025_count_rounded,
    quantile_0.5_count_rounded,
    quantile_0.975_count_rounded,
    target,
    target_end_date,
    reference_date,
    target_end_date_formatted,
    reference_date_formatted
  )

# output folder and file paths for Map Data
output_folder_path <- fs::path(
  base_hub_path, "weekly-summaries", ref_date
)
output_filename <- paste0(ref_date, "_map-data.csv")
output_filepath <- fs::path(
  output_folder_path, output_filename
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
