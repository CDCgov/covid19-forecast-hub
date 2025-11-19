get_truth_data <- function(
  reference_date,
  base_hub_path,
  hub_reports_path,
  included_locations
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
    dplyr::mutate(
      location = forecasttools::us_location_recode(.data$state, "abbr", "code"),
      location_name = forecasttools::us_location_recode(
        .data$state,
        "abbr",
        "name"
      )
    ) |>
    # exclude certain territories
    dplyr::filter(.data$location %in% !!included_locations) |>
    # long name "United States" to "US"
    dplyr::mutate(
      location_name = dplyr::case_match(
        .data$location_name,
        "United States" ~ "US",
        .default = .data$location_name
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
  included_locations,
  first_full_weekending_date
) {
  today <- lubridate::today()
  output_dirpath <- fs::path(base_hub_path, "target-data")
  fs::dir_create(output_dirpath)

  nhsn_data <- forecasttools::pull_nhsn(
    api_endpoint = "https://data.cdc.gov/resource/mpgq-jmmr.json",
    columns = c("totalconfc19newadm"),
    start_date = first_full_weekending_date
  ) |>
    dplyr::rename(
      observation = "totalconfc19newadm",
      date = "weekendingdate"
    ) |>
    dplyr::mutate(
      date = as.Date(.data$date),
      observation = as.numeric(.data$observation),
      jurisdiction = stringr::str_replace(.data$jurisdiction, "USA", "US")
    ) |>
    dplyr::mutate(
      location = forecasttools::us_location_recode(
        .data$jurisdiction,
        "abbr",
        "code"
      ),
      as_of = !!today,
      target = "wk inc covid hosp"
    ) |>
    dplyr::filter(location %in% !!included_locations)

  hubverse_format_nhsn_data <- nhsn_data |> dplyr::select(-"jurisdiction")

  nhsn_data |>
    dplyr::rename(
      value = "observation",
      state = "jurisdiction"
    ) |>
    dplyr::select(-c("as_of", "target")) |>
    readr::write_csv(
      fs::path(output_dirpath, "covid-hospital-admissions.csv")
    )

  raw_nssp_data <- forecasttools::read_tabular(
    fs::path(
      base_hub_path,
      "auxiliary-data",
      "nssp-raw-data",
      "latest",
      ext = "parquet"
    ),
    show_col_types = FALSE
  )

  hubverse_format_nssp_data <- raw_nssp_data |>
    dplyr::filter(county == "All") |>
    dplyr::mutate(
      date = as.Date(.data$week_end),
      observation = as.numeric(.data$percent_visits_covid) / 100,
    ) |>
    dplyr::mutate(
      location = forecasttools::us_location_recode(
        .data$geography,
        "name",
        "code"
      ),
      as_of = !!today,
      target = "wk inc covid prop ed visits"
    ) |>
    dplyr::select(
      "date",
      "observation",
      "location",
      "as_of",
      "target"
    )

  output_file <- fs::path(output_dirpath, "time-series", ext = "parquet")
  forecasttools::read_tabular(output_file) |>
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

included_locations <- setdiff(
  forecasttools::us_location_table$code,
  excluded_locations
)

if (target_data) {
  get_target_data(
    base_hub_path = base_hub_path,
    included_locations = included_locations,
    first_full_weekending_date = first_full_weekending_date
  )
} else {
  get_truth_data(
    reference_date = reference_date,
    base_hub_path = base_hub_path,
    hub_reports_path = hub_reports_path,
    included_locations = included_locations
  )
}
