#' This script fetches observed COVID-19 hospital
#' admissions data for all regions (including US, DC, and Puerto Rico)
#' The data is sourced from the NHSN hospital respiratory
#' data: (https://www.cdc.gov/nhsn/psc/hospital-respiratory-reporting.html).
#'
#' The resulting csv file contains the
#' following columns:
#' - `week_ending_date`: week ending date of
#' observed data per row (Ex: 2024-11-16)
#' - `location`: two-digit FIPS code
#' associated with each state (Ex: 06)
#' - `location_name`: full state name
#' (including "US" for the US state)
#' - `value`: the number of hospital
#' admissions (integer)
#'
#' To get the historical dataset for visualization:
#' Rscript get_covid_hosp_data.R --target-data FALSE \
#'   --reference-date YYYY-MM-DD --base-hub-path ../
#'
#' To get the target COVID-19 hospital admissions data:
#' Rscript get_covid_hosp_data.R --target-data TRUE \
#'   --reference-date YYYY-MM-DD --base-hub-path ../

# set up command line argument parser
parser <- argparser::arg_parser(
  "Fetch and process COVID-19 hospital admissions data."
)
parser <- argparser::add_argument(
  parser,
  "--reference-date",
  type = "character",
  help = "The forecasting reference date in YYYY-MM-DD format (ISO-8601)"
)
parser <- argparser::add_argument(
  parser,
  "--base-hub-path",
  type = "character",
  help = "Path to the COVID-19 forecast hub directory."
)
parser <- argparser::add_argument(
  parser,
  "--hub-reports-path",
  type = "character",
  help = "path to COVIDhub reports directory"
)
parser <- argparser::add_argument(
  parser,
  "--target-data",
  type = "logical",
  help = "If FALSE, fetches NHSN historical data. IF TRUE, gets target data."
)
parser <- argparser::add_argument(
  parser,
  "--first-full-weekending-date",
  help = "Filter data by week ending date",
  type = "character",
  default = "2024-11-09"
)

# read CLAs; get reference date and paths
args <- argparser::parse_args(parser)
reference_date <- args$reference_date
base_hub_path <- args$base_hub_path
hub_reports_path <- args$hub_reports_path
target_data <- args$target_data
first_full_weekending_date <- args$first_full_weekending_date

# gather locations to exclude such that the
# only territories are the 50 US states, DC,
# and PR
exclude_territories_path <- fs::path(
  base_hub_path,
  "auxiliary-data",
  "excluded_territories.toml"
)
if (fs::file_exists(exclude_territories_path)) {
  exclude_territories_toml <- RcppTOML::parseTOML(exclude_territories_path)
  excluded_locations <- exclude_territories_toml$locations
} else {
  stop("TOML file not found: ", exclude_territories_path)
}


if (target_data) {
  # fetch some NHSN COVID-19 hospital admissions
  covid_data <- forecasttools::pull_nhsn(
    # https://data.cdc.gov/resource/mpgq-jmmr.json
    api_endpoint = "https://data.cdc.gov/resource/ua7e-t2fy.json",
    columns = c("totalconfc19newadm"),
    start_date = first_full_weekending_date
  ) |>
    dplyr::rename(
      value = totalconfc19newadm,
      date = weekendingdate,
      state = jurisdiction
    ) |>
    dplyr::mutate(
      date = as.Date(date),
      value = as.numeric(value),
      state = stringr::str_replace(state, "USA", "US")
    )

  formatted_data <- covid_data |>
    dplyr::mutate(location = forecasttools::us_loc_abbr_to_code(state)) |>
    dplyr::filter(!(location %in% excluded_locations))
  output_dirpath <- "target-data/"
  readr::write_csv(
    formatted_data,
    file.path(output_dirpath, "covid-hospital-admissions.csv")
  )
}

if (!target_data) {
  # fetch all NHSN COVID-19 hospital admissions
  covid_data <- forecasttools::pull_nhsn(
    api_endpoint = "https://data.cdc.gov/resource/mpgq-jmmr.json",
    columns = c("totalconfc19newadm"),
  ) |>
    dplyr::rename(
      value = totalconfc19newadm,
      date = weekendingdate,
      state = jurisdiction
    ) |>
    dplyr::mutate(
      date = as.Date(date),
      value = as.numeric(value),
      state = stringr::str_replace(
        state,
        "USA",
        "US"
      )
    )
  truth_data <- covid_data |>
    dplyr::mutate(
      location = forecasttools::us_loc_abbr_to_code(state),
      location_name = forecasttools::location_lookup(
        location,
        location_input_format = "hub",
        location_output_format = "long_name"
      )
    ) |>
    # exclude certain territories
    dplyr::filter(!(location %in% excluded_locations)) |>
    # long name "United States" to "US"
    dplyr::mutate(
      location_name = dplyr::if_else(
        location_name == "United States",
        "US",
        location_name
      )
    ) |>
    dplyr::select(
      week_ending_date = date,
      location,
      location_name,
      value
    )
  # output folder and file paths for Truth Data
  output_folder_path <- fs::path(
    hub_reports_path, "weekly-summaries", reference_date
  )
  output_filename <- paste0(
    reference_date, "_covid_target_hospital_admissions_data.csv"
  )
  output_filepath <- fs::path(output_folder_path, output_filename)
  # determine if the output folder exists,
  # create it if not
  fs::dir_create(output_folder_path)
  message("Directory is ready: ", output_folder_path)
  # check if the file exists, and if not,
  # save to csv, else throw an error
  if (!fs::file_exists(output_filepath)) {
    readr::write_csv(truth_data, output_filepath)
    message("File saved as: ", output_filepath)
  } else {
    stop("File already exists: ", output_filepath)
  }
}
