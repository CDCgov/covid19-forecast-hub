get_truth_data <- function(
  reference_date,
  base_hub_path,
  hub_reports_path,
  excluded_locations
) {
  covid_data <- forecasttools::pull_nhsn(
    api_endpoint = "https://data.cdc.gov/resource/mpgq-jmmr.json",
    columns = c("totalconfc19newadm"),
  ) |>
    dplyr::rename(
      value = "totalconfc19newadm",
      date = "weekendingdate",
      state = "jurisdiction"
    ) |>
    dplyr::mutate(
      date = as.Date(.data$date),
      value = as.numeric(.data$value),
      state = stringr::str_replace(
        .data$state,
        "USA",
        "US"
      )
    ) |>
    dplyr::filter(!stringr::str_detect(.data$state, "Region")) |>
    dplyr::mutate(
      location = forecasttools::us_location_recode(.data$state, "abbr", "code"),
      location_name = forecasttools::us_location_recode(
        .data$state,
        "abbr",
        "name"
      )
    ) |>
    # exclude certain territories
    dplyr::filter(!(.data$location %in% !!excluded_locations)) |>
    # long name "United States" to "US"
    dplyr::mutate(
      location_name = dplyr::if_else(
        .data$location_name == "United States",
        "US",
        .data$location_name
      )
    ) |>
    dplyr::select(
      week_ending_date = "date",
      "location",
      "location_name",
      "value"
    )
  # output folder and file paths for Truth Data
  output_folder_path <- fs::path(
    hub_reports_path,
    "weekly-summaries",
    reference_date
  )
  output_filename <- paste0(
    reference_date,
    "_covid_target_hospital_admissions_data"
  )
  output_filepath <- fs::path(output_folder_path, output_filename, ext = "csv")
  fs::dir_create(output_folder_path)
  message("Directory is ready: ", output_folder_path)
  if (!fs::file_exists(output_filepath)) {
    readr::write_csv(covid_data, output_filepath)
    message("File saved as: ", output_filepath)
  } else {
    stop("File already exists: ", output_filepath)
  }
}


get_target_data <- function(
  base_hub_path,
  excluded_locations,
  first_full_weekending_date
) {
  today <- lubridate::today()
  output_dirpath <- fs::path(base_hub_path, "target-data")
  fs::dir_create(output_dirpath)

  raw_nhsn_data <- forecasttools::pull_nhsn(
    api_endpoint = "https://data.cdc.gov/resource/mpgq-jmmr.json",
    columns = c("totalconfc19newadm"),
    start_date = first_full_weekending_date
  )

  output_file <- fs::path(output_dirpath, "time-series", ext = "parquet")
  hubverse_format_nhsn_data <- raw_nhsn_data |>
    dplyr::rename(
      observation = "totalconfc19newadm",
      date = "weekendingdate",
      state = "jurisdiction"
    ) |>
    dplyr::mutate(
      date = as.Date(.data$date),
      observation = as.numeric(.data$observation),
      state = stringr::str_replace(.data$state, "USA", "US")
    ) |>
    dplyr::filter(!stringr::str_detect(.data$state, "Region")) |>
    dplyr::mutate(
      location = forecasttools::us_location_recode(.data$state, "abbr", "code"),
      as_of = !!today,
      target = "wk inc covid hosp"
    ) |>
    dplyr::filter(!(location %in% !!excluded_locations))

  hubverse_format_nhsn_data |>
    dplyr::rename(
      value = observation
    ) |>
    dplyr::select(-c("as_of", "target")) |>
    readr::write_csv(
      fs::path(output_dirpath, "covid-hospital-admissions.csv")
    )

  raw_nssp_data <- readr::read_csv(
    fs::path(
      base_hub_path,
      "auxiliary-data",
      "nssp-raw-data",
      "latest",
      ext = "csv"
    ),
    show_col_types = FALSE
  )

  hubverse_format_nssp_data <- raw_nssp_data |>
    dplyr::filter(county == "All") |>
    dplyr::mutate(
      date = as.Date(.data$week_end),
      observation = as.numeric(.data$percent_visits_covid) / 100,
      location = ifelse(
        .data$fips == "00000",
        "US",
        stringr::str_sub(.data$fips, 1, 2)
      )
    ) |>
    dplyr::mutate(
      state = forecasttools::us_location_recode(.data$geography, "name", "abbr"),
      location = forecasttools::us_location_recode(.data$geography, "name", "code"),
      as_of = !!today,
      target = "wk inc covid prop ed visits"
    ) |>
    dplyr::select(
      "date",
      "state",
      "observation",
      "location",
      "as_of",
      "target"
    )

  forecasttools::read_tabular_file(output_file) |>
    dplyr::bind_rows(hubverse_format_nhsn_data, hubverse_format_nssp_data) |>
    forecasttools::write_tabular_file(output_file)
}


parser <- argparser::arg_parser(
  "Fetch and save COVID-19 hospital admissions data."
)
parser <- argparser::add_argument(
  parser,
  "--reference-date",
  type = "character",
  help = "The forecasting reference date in YYYY-MM-DD format (ISO-8601)."
)
parser <- argparser::add_argument(
  parser,
  "--base-hub-path",
  type = "character",
  help = "Path to the COVID-19 forecast hub directory (default: cwd).",
  default = "."
)
parser <- argparser::add_argument(
  parser,
  "--hub-reports-path",
  type = "character",
  help = "Path to COVID Hub reports directory."
)
parser <- argparser::add_argument(
  parser,
  "--target-data",
  type = "logical",
  help = "If FALSE, fetches NHSN historical data for the webpage.
  If TRUE, gets target data."
)
parser <- argparser::add_argument(
  parser,
  "--first-full-weekending-date",
  help = "Filter data by week ending date.",
  type = "character",
  default = "2024-11-09"
)

args <- argparser::parse_args(parser)
reference_date <- args$reference_date
base_hub_path <- args$base_hub_path
hub_reports_path <- args$hub_reports_path
target_data <- args$target_data
first_full_weekending_date <- args$first_full_weekending_date

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
  get_target_data(
    base_hub_path = base_hub_path,
    excluded_locations = excluded_locations,
    first_full_weekending_date = first_full_weekending_date
  )
} else {
  get_truth_data(
    reference_date = reference_date,
    base_hub_path = base_hub_path,
    hub_reports_path = hub_reports_path,
    excluded_locations = excluded_locations
  )
}
