parser <- argparser::arg_parser(
  "Fetch and process COVID-19 hospital admissions data"
)
parser <- argparser::add_argument(
  parser,
  "--first_full_weekending_date",
  help = "Filter data by week ending date",
  type = "character",
  default = "2024-11-09"
)

args <- argparser::parse_args(parser)
first_full_weekending_date <- as.Date(args$first_full_weekending_date)

# Fetch covid-19 data
covid_data <- RSocrata::read.socrata(
  url = "https://data.cdc.gov/resource/ua7e-t2fy.json"
) |>
  dplyr::filter(weekendingdate >= first_full_weekending_date) |>
  dplyr::select(jurisdiction, weekendingdate, totalconfc19hosppats) |>
  dplyr::rename(
    value = totalconfc19hosppats,
    date = weekendingdate,
    state = jurisdiction
  ) |>
  dplyr::mutate(
    date = as.Date(date),
    value = as.numeric(value),
    state = stringr::str_replace(state, "USA", "US")
  )

loc_df <- read.csv("target-data/locations.csv")

exclude_data <- jsonlite::fromJSON("auxiliary-data/exclude_ensemble.json")
excluded_locations <- exclude_data$locations

formatted_data <- covid_data |>
  dplyr::left_join(loc_df, by = c("state" = "abbreviation")) |>
  dplyr::filter(!(location %in% excluded_locations)) |>
  dplyr::select(date, state, value, location) 

output_dirpath <- "target-data/"

write.csv(
  formatted_data,
  file.path(output_dirpath, "covid-hospital-admissions.csv"),
  row.names = FALSE
)
