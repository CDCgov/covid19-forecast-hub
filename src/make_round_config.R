get_reference_dates <- function(start_date, end_date, weekday = "Saturday") {
  start_date <- as.Date(start_date)
  # Find the first occurrence of the specified weekday on or after start_date
  start_date <- lubridate::ceiling_date(
    start_date,
    unit = "week",
    week_start = weekday
  )

  end_date <- as.Date(end_date)

  # Generate a sequence of weeks
  seq.Date(from = start_date, to = end_date, by = "1 week")
}

get_target_dates <- function(ref_dates, horizon_range) {
  # Calculate target dates by adding the horizon range (in weeks) to each
  # reference date
  outer(ref_dates, horizon_range * 7, `+`) |>
    unique() |>
    sort()
}

create_new_round <- function(
    hub_path,
    horizon_range,
    location,
    start_date,
    end_date,
    weekday = "Saturday",
    schema_version = hubUtils::get_version_hub(hub_path)) {
  options(hubAdmin.schema_version = schema_version)

  ref_dates <- get_reference_dates(start_date, end_date, weekday)
  target_dates <- get_target_dates(ref_dates, horizon_range)

  origin_date <- hubAdmin::create_task_id(
    "reference_date",
    required = NULL,
    optional = as.character(ref_dates)
  )

  location <- hubAdmin::create_task_id(
    "location",
    required = NULL,
    optional = location
  )

  horizon <- hubAdmin::create_task_id(
    "horizon",
    required = NULL,
    optional = horizon_range
  )

  target_end_date <- hubAdmin::create_task_id(
    "target_end_date",
    required = NULL,
    optional = as.character(target_dates)
  )

  target <- hubAdmin::create_task_id(
    "target",
    required = NULL,
    optional = c("wk inc covid hosp", "wk inc covid prop ed visits")
  )

  task_ids <- hubAdmin::create_task_ids(
    origin_date,
    location,
    horizon,
    target_end_date,
    target
  )

  quantile_out_type <- hubAdmin::create_output_type_quantile(
    required = c(0.01, 0.025, seq(0.05, 0.95, by = 0.05), 0.975, 0.99),
    is_required = FALSE,
    value_type = "double",
    value_minimum = 0
  )

  sample_out_type <- hubAdmin::create_output_type_sample(
    is_required = FALSE,
    output_type_id_type = "character",
    max_length = 15L,
    min_samples_per_task = 200L,
    max_samples_per_task = 200L,
    compound_taskid_set = "location",
    value_type = "double",
    value_minimum = 0
  )

  target_metadata_admissions <- hubAdmin::create_target_metadata_item(
    target_id = "wk inc covid hosp",
    target_name = "incident covid hospitalizations",
    target_units = "count",
    target_keys = list(target = "wk inc covid hosp"),
    target_type = "continuous",
    description = "This target represents the count of new hospitalizations in the week ending on the date [horizon] weeks after the reference_date, on the target_end_date.", # nolint
    is_step_ahead = TRUE,
    time_unit = "week"
  )
  target_metadata_ed_visits <- hubAdmin::create_target_metadata_item(
    target_id = "wk inc covid prop ed visits",
    target_name = "proportion of weekly incident ED visits due to COVID-19",
    target_units = "proportion",
    target_keys = list(target = "wk inc covid prop ed visits"),
    target_type = "continuous",
    description = "This target represents the proportion of emergency department visits due to COVID-19 in the week ending on the date [horizon] weeks after the reference_date, on the target_end_date.", # nolint
    is_step_ahead = TRUE,
    time_unit = "week"
  )

  model_task_hosp_admissions <- hubAdmin::create_model_task(
    task_ids = task_ids,
    output_type = hubAdmin::create_output_type(
      quantile_out_type,
      sample_out_type
    ),
    target_metadata = hubAdmin::create_target_metadata(
      target_metadata_admissions,
      target_metadata_ed_visits
    )
  )

  round <- hubAdmin::create_round(
    round_id_from_variable = TRUE,
    round_id = "reference_date",
    model_tasks = hubAdmin::create_model_tasks(model_task_hosp_admissions),
    submissions_due = list(
      relative_to = "reference_date",
      start = -6L,
      end = -3L
    )
  )

  return(round)
}


parser <- argparser::arg_parser("Create a new round config for the COVIDhub")
parser <- argparser::add_argument(
  parser,
  "--schema-version",
  help = "Character string specifying the json schema version.",
  type = "character",
  default = "v5.0.0"
)
parser <- argparser::add_argument(
  parser,
  "--hub-path",
  help = "Path to the Covid19 forecast hub directory.",
  default = "."
)

parser <- argparser::add_argument(
  parser,
  "--horizon-range",
  type = "integer",
  default = -1:3,
  help = "Horizon range in weeks. (default: -1:3)."
)
parser <- argparser::add_argument(
  parser,
  "--location",
  type = "character",
  default = c(
    "US",
    "01",
    "02",
    "04",
    "05",
    "06",
    "08",
    "09",
    "10",
    "11",
    "12",
    "13",
    "15",
    "16",
    "17",
    "18",
    "19",
    "20",
    "21",
    "22",
    "23",
    "24",
    "25",
    "26",
    "27",
    "28",
    "29",
    "30",
    "31",
    "32",
    "33",
    "34",
    "35",
    "36",
    "37",
    "38",
    "39",
    "40",
    "41",
    "42",
    "44",
    "45",
    "46",
    "47",
    "48",
    "49",
    "50",
    "51",
    "53",
    "54",
    "55",
    "56",
    "72"
  ),
  help = "Location codes for forecasting jurisdiction.
    (default: 50 states, DC, US)."
)
parser <- argparser::add_argument(
  parser,
  "--start-date",
  type = "character",
  default = paste(
    if (lubridate::month(Sys.Date()) > 9L) {
      lubridate::year(Sys.Date())
    } else {
      lubridate::year(Sys.Date()) - 1L
    },
    "11", "01",
    sep = "-"
  ),
  help = "Season start date in YYYY-MM-DD format. Defaults to 1st November of current season." # nolint
)

parser <- argparser::add_argument(
  parser,
  "--end-date",
  type = "character",
  default = paste(
    if (lubridate::month(Sys.Date()) > 9L) {
      lubridate::year(Sys.Date()) + 1
    } else {
      lubridate::year(Sys.Date())
    },
    "09", "30",
    sep = "-"
  ),
  help = "Season end date in YYYY-MM-DD format. Defaults to 30th September of current season." # nolint
)

parser <- argparser::add_argument(
  parser,
  "--weekday",
  type = "character",
  default = "Saturday",
  help = "Reference date weekday. Defaults to Saturday."
)

parser <- argparser::add_argument(
  parser,
  "--overwrite",
  type = "logical",
  default = FALSE,
  help = "Whether to overwrite an existing config file or append new rounds to it. Defaults to FALSE." # nolint
)

args <- argparser::parse_args(parser)
hub_path <- args$hub_path
start_date <- args$start_date
end_date <- args$end_date
weekday <- args$weekday
horizon_range <- args$horizon_range
location <- args$location
schema_version <- args$schema_version
overwrite <- args$overwrite

round <- create_new_round(
  hub_path,
  horizon_range,
  location,
  start_date,
  end_date,
  weekday,
  schema_version
)

tasks_config_path <- fs::path(hub_path, "hub-config", "tasks.json")

if (overwrite || !file.exists(tasks_config_path)) {
  new_task_config <- hubAdmin::create_config(hubAdmin::create_rounds(round))
  if (overwrite && file.exists(tasks_config_path)) {
    cli::cli_alert_info(
      "Overwriting existing {.file tasks.json} with new config"
    )
  }
  if (!file.exists(tasks_config_path)) {
    cli::cli_alert_info(
      "Creating new {.file tasks.json} with new round"
    )
  }
} else {
  cli::cli_alert_info(
    "Existing config found, adding a new round"
  )
  existing_task_config <- hubUtils::read_config(hub_path, config = c("tasks"))
  new_task_config <- hubAdmin::append_round(existing_task_config, round)
}

hubAdmin::write_config(new_task_config, hub_path = hub_path, overwrite = TRUE)

valid_task_config <- hubAdmin::validate_config(
  hub_path = hub_path,
  config = c("tasks"),
  schema_version = "from_config"
)
if (isFALSE(valid_task_config)) {
  cli::cli_alert_danger("Generated task config (tasks.json) is invalid")
  stop()
}
cli::cli_h1("New round added to {.file tasks.json}")
