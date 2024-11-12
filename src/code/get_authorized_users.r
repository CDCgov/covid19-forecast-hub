
hub_path <- "."
output_path <- "auxiliary-data/"

yml_files <- list.files(file.path(hub_path, "model-metadata"),
  pattern = "\\.ya?ml$", full.names = TRUE
)

extract_metadata <- function(file) {
  yml_data <- yaml::yaml.load_file(file)
  team_abbr <- ifelse("team_abbr" %in% names(yml_data), yml_data$team_abbr, NA)
  model_abbr <- ifelse(
    "model_abbr" %in% names(yml_data), yml_data$model_abbr, NA
  )
  designated_user <- if ("designated_github_users" %in% names(yml_data)) {
    if (is.vector(yml_data$designated_github_users)) {
      paste(yml_data$designated_github_users, collapse = ", ")
    } else {
      yml_data$designated_github_users
    }
  } else {
    NA
  }

  return(list(
    team_abbr = team_abbr,
    model_abbr = model_abbr,
    designated_github_users = designated_user
  ))
}

metadata_list <- purrr::map(yml_files, extract_metadata)
data_df <- do.call(rbind, lapply(metadata_list, as.data.frame))
colnames(data_df) <- c("team_name", "model_name", "designated_users")

output <- glue::glue(
  "{data_df$team_name}-{data_df$model_name} {data_df$designated_users}"
)

writeLines(output, file.path(output_path, "authorized_users.txt"))