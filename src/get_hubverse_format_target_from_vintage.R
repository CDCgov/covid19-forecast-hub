#' Transform legacy formatted target data
#' `covid-hospital-admissions.csv` to
#' Hubverse format `time-series.parquet`.

format_to_hubverse <- function(filepath) {
  as_of_date <-
    readr::read_csv(filepath, show_col_types = FALSE) |>
    dplyr::mutate(
      as_of = as.Date(
        stringr::str_extract(filepath, "\\d{4}-\\d{2}-\\d{2}")
      ),
      target = "wk inc covid hosp"
    ) |>
    dplyr::rename(
      observation = value
    )
}

parser <- argparser::arg_parser("Format target data to Hubverse format")
parser <- argparser::add_argument(
  parser,
  "--archive-path",
  help = "Path to the target-data archive directory.",
  default = "auxiliary-data/target-data-archive"
)
parser <- argparser::add_argument(
  parser,
  "--output-dirpath",
  help = "Path to the output directory.",
  default = "target-data"
)

args <- argparser::parse_args(parser)
archive_path <- args$archive_path
output_dirpath <- args$output_dirpath

output_file <- fs::path(output_dirpath, "time-series", ext = "parquet")

fs::dir_ls(archive_path) |>
  purrr::map_dfr(
    format_to_hubverse
  ) |>
  arrow::write_parquet(
    output_file
  )
