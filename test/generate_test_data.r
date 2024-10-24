# Load required libraries
library(dplyr)
library(lubridate)

# Define the states and their corresponding FIPS codes
states <- data.frame(
  location = c("01", "02", "04", "05", "06", "08", "09", "10", "11", "12", "13",
               "15", "16", "17", "18", "19", "20", "21", "22", "23", "24",
               "25", "26", "27", "28", "29", "30", "31", "32", "33", "34",
               "35", "36", "37", "38", "39", "40", "41", "42", "44", "45",
               "46", "47", "48", "49", "50", "51", "53", "54", "55", "56"),
  location_name = c("Alabama", "Alaska", "Arizona", "Arkansas", "California",
                    "Colorado", "Connecticut", "Delaware",
                    "District of Columbia", "Florida", "Georgia", "Hawaii",
                    "Idaho", "Illinois", "Indiana", "Iowa", "Kansas",
                    "Kentucky", "Louisiana", "Maine", "Maryland",
                    "Massachusetts", "Michigan", "Minnesota", "Mississippi",
                    "Missouri", "Montana", "Nebraska", "Nevada",
                    "New Hampshire", "New Jersey", "New Mexico", "New York",
                    "North Carolina", "North Dakota", "Ohio", "Oklahoma",
                    "Oregon", "Pennsylvania", "Rhode Island", "South Carolina",
                    "South Dakota", "Tennessee", "Texas", "Utah", "Vermont",
                    "Virginia", "Washington", "West Virginia", "Wisconsin",
                    "Wyoming")
)

# Set seed for reproducibility
set.seed(123)

# Generate synthetic data
unique_dates <- seq(as.Date("2024-01-06"), as.Date("2024-04-27"), by = "week")

# Create a unique combination of date and location
fake_data <- expand.grid(
  date = unique_dates,
  location = states$location
) %>%
  mutate(
    location_name = states$location_name[match(location, states$location)],
    value = sample(1:100, nrow(.), replace = TRUE)
  )


# Display the generated data
write.csv(
  fake_data, file.path("target-data", "test-hospital-admissions.csv")
)
