# Run via: Rscript ./src/get_authorized_users.R

hub_path <- "."
output_path <- "auxiliary-data/"

yml_files <- list.files(
  file.path(hub_path, "model-metadata"),
  pattern = "\\.ya?ml$",
  full.names = TRUE
)

extract_metadata <- function(file) {
  yml_data <- yaml::yaml.load_file(file)
  team_abbr <- ifelse(
    "team_abbr" %in% names(yml_data),
    yml_data$team_abbr,
    NA_character_
  )
  model_abbr <- ifelse(
    "model_abbr" %in% names(yml_data),
    yml_data$model_abbr,
    NA
  )
  designated_user <- ifelse(
    "designated_github_users" %in% names(yml_data),
    paste(yml_data$designated_github_users, collapse = ", "),
    NA
  )

  return(list(
    team_abbr = team_abbr,
    model_abbr = model_abbr,
    designated_github_users = designated_user
  ))
}


dir.create(output_path, showWarnings = FALSE, recursive = TRUE)
metadata <- purrr::map(yml_files, extract_metadata)
data_df <- do.call(rbind, lapply(metadata, as.data.frame))

colnames(data_df) <- c("team_name", "model_name", "designated_users")


json_list <- purrr::pmap(
  data_df,
  function(team_name, model_name, designated_users) {
    users <- if (is.na(designated_users)) {
      NA
    } else {
      I(strsplit(designated_users, "\\s*,\\s*")[[1]])
    }
    return(list(
      model = paste(team_name, model_name, sep = "-"),
      authorized_github_users = users
    ))
  }
)

jsonlite::write_json(
  json_list,
  path = file.path(output_path, "authorized_users.json"),
  pretty = TRUE,
  auto_unbox = TRUE
)
