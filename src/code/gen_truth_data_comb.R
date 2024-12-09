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
#' Rscript gen_truth_data_comb.R --reference_date 2024-11-23 --base_hub_path ../../

argparse::ArgumentParser(description = "Save Truth Data as CSV.") %>%
  add_argument(
    "--reference_date", 
    type = "character", 
    help = "The reference date for the forecast in YYYY-MM-DD format (ISO-8601)"
  ) %>%
  add_argument(
    "--base_hub_path", 
    type = "character", 
    help = "Path to the Covid19 forecast hub directory."
  )

args <- parser$parse_args()
reference_date <- args$reference_date
base_hub_path <- args$base_hub_path

exclude_data_path <- fs::path(base_hub_path, "auxiliary-data", "excluded_territories.json")
if (!fs::file_exists(exclude_data_path)) {
  stop("Exclude locations file not found: ", exclude_data_path)
}
exclude_data <- jsonlite::fromJSON(exclude_data_path)
excluded_locations <- exclude_data$locations

covid_data <- forecasttools::pull_nhsn(
  api_endpoint = "https://data.cdc.gov/resource/mpgq-jmmr.json",
  columns = c("totalconfc19newadm")
) %>%
  dplyr::rename(
    value = totalconfc19newadm,
    date = weekendingdate,
    state = jurisdiction
  ) %>%
  dplyr::mutate(
    date = as.Date(date)
  )

covid_data <- covid_data %>%
  dplyr::filter(!state %in% excluded_locations)

output_file_path <- paste0("truth_data_", reference_date, ".csv")

covid_data %>%
  dplyr::mutate(
    week_ending_date = format(date, "%Y-%m-%d"),
    location_name = dplyr::recode(state, `06` = "US") 
  ) %>%
  dplyr::select(week_ending_date, state, location_name, value) %>%
  write.csv(., output_file_path, row.names = FALSE)

cat("Truth data successfully saved to: ", output_file_path, "\n")

