#' Generate the Truth Data file containing 
#' the most recent observed NHSN hospital 
#' admissions data.
#'
#' This script fetches the most recent 
#' observed COVID-19 hospital
#' admissions data for all regions 
#' (including US, DC, and Puerto Rico) 
#' and processes it into the required format. 
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
#' To run:
#' Rscript gen_truth_data.R --reference_date 2024-11-23 --base_hub_path ../../


# this file will be combined with get_target_data.R

# set up command line argument parser
parser <- argparse::ArgumentParser(
  description = "Save Truth Data as CSV.")
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
reference_date <- args$reference_date
base_hub_path <- args$base_hub_path


# gather locations to exclude such that the 
# only territories are the 50 US states, DC, 
# and PR
exclude_data_path <- fs::path(
  base_hub_path, 
  "auxiliary-data", 
  "excluded_territories.json")
if (!fs::file_exists(exclude_data_path)) {
  stop("Exclude locations file not found: ", exclude_data_path)
}
exclude_data <- jsonlite::fromJSON(exclude_data_path)
excluded_locations <- exclude_data$locations

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

# convert state abbreviation to location code 
# and to long name
covid_data <- covid_data |>
  dplyr::mutate(
    location = forecasttools::us_loc_abbr_to_code(state), 
    location_name = forecasttools::location_lookup(
      location, 
      location_input_format = "hub", 
      location_output_format = "long_name")
  ) |>
  # exclude certain territories
  dplyr::filter(!(location %in% excluded_locations)) |>
  # long name "United States" to "US"
  dplyr::mutate(
    location_name = dplyr::if_else(
      location_name == "United States", 
      "US", 
      location_name)
  )

# filter and format the data
truth_data <- covid_data |>
  dplyr::select(
    week_ending_date = date, 
    location, 
    location_name, 
    value
  )

# output folder and file paths for Truth Data
output_folder_path <- fs::path(base_hub_path, "weekly-summaries", reference_date)
output_filename <- paste0(reference_date, "_truth-data.csv")
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