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
#' Rscript gen_forecast_data.R --reference_date 2024-11-23

library("magrittr") # for %>%


# set up command line argument parser
parser <- argparse::ArgumentParser(
  description = "Save Truth Data as CSV.")
parser$add_argument(
  "--reference_date", 
  type = "character", 
  help = "The reference date for the forecast in YYYY-MM-DD format (ISO-8601)"
)

# read CLAs; get reference date
args <- parser$parse_args()
ref_date <- args$reference_date

# store base metadata path for use later
model_metadata_path <- "../../model-metadata/" 

# get `covid19-forecast-hub` content
base_hub_path <- "../../"  
hub_content <- hubData::connect_hub(base_hub_path)
current_forecasts <- hub_content %>%
  dplyr::filter(reference_date == as.Date(ref_date)) %>%
  hubData::collect_hub()

# add forecast team and model name
current_forecasts <- current_forecasts %>%
  dplyr::mutate(
    # extract model_name and team_name from 
    # YAML metadata files
    forecast_team = sapply(model_id, function(model_id) {
      model_yaml_path <- file.path(model_metadata_path, paste0(model_id, ".yml"))
      # check if the YAML file exists
      if (file.exists(model_yaml_path)) {
        model_metadata <- yaml::read_yaml(model_yaml_path)
        # extract team_name
        return(model_metadata$team_name)
      } else {
        return(NA) # NA if file doesn't exist
      }
    }),
    forecast_fullnames = sapply(model_id, function(model_id) {
      model_yaml_path <- file.path(model_metadata_path, paste0(model_id, ".yml"))
      if (file.exists(model_yaml_path)) {
        model_metadata <- yaml::read_yaml(model_yaml_path)
        return(model_metadata$model_name)
      } else {
        return(NA) # NA if file doesn't exist
      }
    })
  )

# pivot forecast data and prepare final output
all_forecasts_data <- forecasttools::pivot_hubverse_quantiles_wider(
  hubverse_table = current_forecasts,
  pivot_quantiles = c(
    "quantile_0.025" = 0.025, 
    "quantile_0.25" = 0.25, 
    "quantile_0.5" = 0.5, 
    "quantile_0.75" = 0.75, 
    "quantile_0.975" = 0.975)
)

# get data for All Forecasts file
all_forecasts_data <- forecasttools::pivot_hubverse_quantiles_wider(
  hubverse_table = current_forecasts,
  pivot_quantiles = c(
    "quantile_0.025" = 0.025, 
    "quantile_0.25" = 0.25, 
    "quantile_0.5" = 0.5, 
    "quantile_0.75" = 0.75, 
    "quantile_0.975" = 0.975)  
) %>%
  # convert location codes to full location 
  # names and to abbreviations
  dplyr::mutate(
    location_name = forecasttools::location_lookup(
      location, 
      location_input_format = "hub", 
      location_output_format = "long_name"
    ),
    abbreviation = forecasttools::us_loc_code_to_abbr(location)
  ) %>%
  # round the quantiles to nearest integer 
  # for rounded versions
  dplyr::mutate(
    quantile_0.025_rounded = round(quantile_0.025),
    quantile_0.25_rounded = round(quantile_0.25),
    quantile_0.5_rounded = round(quantile_0.5),
    quantile_0.75_rounded = round(quantile_0.75),
    quantile_0.975_rounded = round(quantile_0.975)
  ) %>%
  dplyr::select(
    location_name,
    abbreviation,
    horizon,
    forecast_date = reference_date,  # rename reference_date to forecast_date
    target_end_date,
    model = model_id, # rename model_id to model
    quantile_0.025,
    quantile_0.25,
    quantile_0.5,
    quantile_0.75,
    quantile_0.975,
    quantile_0.025_rounded,
    quantile_0.25_rounded,
    quantile_0.5_rounded,
    quantile_0.75_rounded,
    quantile_0.975_rounded,
    forecast_team,
    forecast_fullnames
  )

# determine if output folder exists, create
# if it doesn't
folder_path <- file.path("../../weekly-summaries/", ref_date)
if (!dir.exists(folder_path)) {
  dir.create(folder_path, recursive = TRUE)
  message("Directory created: ", folder_path)
} else {
  message("Directory already exists: ", folder_path)
}

# check if Truth Data for reference date 
# already exist, if not, save to csv
output_filename <- paste0(ref_date, "_all-forecasts.csv")
output_filepath <- file.path(folder_path, output_filename)
if (!file.exists(output_filepath)) {
  readr::write_csv(all_forecasts_data, output_filepath)
  message("File saved as: ", output_filepath)
} else {
  message("File already exists: ", output_filepath)
}