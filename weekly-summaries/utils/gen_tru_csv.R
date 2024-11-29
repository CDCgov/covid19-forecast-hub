#' Generate the `truth_data.csv` file 
#' containing the most recent observed 
#' hospitalization data.
#'
#' This script fetches the most recent 
#' observed [COVID-19 or flu hospital
#' admissions data for all states 
#' (including US, DC, and Puerto Rico) 
#' and processes it into the required format 
#' for `truth_data.csv`. The data is sourced 
#' from the CDC's COVID-19 hospitalization
#' data (using the `get_target_data.r` script).
#'
#' The resulting `truth_data.csv` will contain 
#' the following columns:
#' - `week_ending_date`: the week ending date 
#' for the observed data
#' - `location`: two-digit FIPS code associated 
#' with the state
#' - `location_name`: full state name 
#' (including "US" for the US state)
#' - `value`: the number of hospital 
#' admissions (integer)
#'
#' The file is saved in the 
#' `weekly-summaries/output/` directory as 
#' `truth_data.csv`.


# use get_target_data.R
source("get_target_data.R")

# load the formatted data from get_target_data.R)
formatted_data <- covid_data %>%
  dplyr::filter(!location %in% excluded_locations) %>%
  dplyr::select(
    week_ending_date,
    location,
    location_name,
    value
  )

# save to CSV
readr::write_csv(formatted_data, "../output/truth_data.csv")

