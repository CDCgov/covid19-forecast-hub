# Inform Division Forecast Visualization Data

The following data

* are generated partially from COVID Hub submissions.
* are generated partially from COVID Hub truth data.
* are used by the Inform Division for visualization.
* follows a particular schema, outlined below.

Sections below come from the (2024-11-29) version of Inform's data dictionary file:

__Map Component__ (`map.csv`)

_Contains data from the ensemble COVID or flu forecast for all states (including US, DC and Puerto Rico) and for 7 and 14 day forecast targets_


location_name (string): state name column. Includes US 
(Ex: Alabama 
quantile_0.025_per100k (numeric): 0.025 quantile forecast value as a rate per 100k 
(Ex: 1.12777351608532 
quantile_0.5_per100k (numeric) 0.5 quantile forecast value as a rate per 100k 
quantile_0.975_per100k (numeric) 0.975 quantile forecast value as a rate per 100k 
quantile_0.025_count (numeric): 0.025 quantile forecast value 
(Ex: 3754.07763671875 
quantile_0.5_count (numeric) 0.5 quantile forecast value 
quantile_0.975_count (numeric) 0.975 quantile forecast value 
quantile_0.025_per100k_rounded (numeric): forecasted value as a rate per 100k, rounded to 2 places 
(Ex: 3.57 
quantile_0.5_ per100k_rounded (numeric): forecasted value as a rate per 100k, rounded to 2 places 
quantile_0.975_ per100k_rounded (numeric): forecasted value as a rate per 100k, rounded to 2 places 
quantile_0.025_count_rounded (numeric): 0.025 quantile forecast value, rounded up to the nearest integer 
(Ex: 3755 
quantile_0.5_count_rounded (numeric) 0.5 quantile forecast value, rounded up to the nearest integer 
quantile_0.975_count_rounded (numeric) 0.975 quantile forecast value, rounded up to the nearest integer 
target (string): description of forecast target date 
(Ex: 7 day ahead inc hosp 
target_end_date (date): target date for the forecast 
(Ex: 2024-11-30 
reference_date (date): date that the forecast was generated 
(Ex: 2024-11-23)
target_end_date_formatted (string): target date for the forecast, prettily re-formatted as a string 
(Ex: “November 30, 2024”)
reference_date_formatted (string): date that the forecast was generated, prettily re-formatted as a string (Ex: “November 23, 2024”)

 

__Timeseries Component__ (`all_forecasts.csv`):

_Contains all the available COVID or flu models submitted in a given week for all states (including US, DC and Puerto Rico)._


location_name (string): full state name for the forecast (note: US is not spelled out) 

(Ex: Alabama, US 

abbreviation (string): abbreviated state name 

(Ex: AL 

horizon (numeric): time horizon for the forecast. Currently using time horizons 0, 1, 2, 3 

(Ex: 2 

forecast_date (date): date that forecast was generated 

(Ex: 2024-11-23 

target_end_date (date): target date for forecast 

(Ex: 2024-11-30 

model (string): name of the model, pulled from the folder names in the model-output section of the forecast repos 

(Ex: FluSight-ensemble, CEPH-Rtrend_fluH 

quantile_0.025 (numeric): 0.025 quantile forecast value 

(Ex: 922.475 

quantile_0.25 (numeric): 0.25 quantile forecast value 

quantile_0.5 (numeric): 0.5 quantile forecast value 

quantile_0.75 (numeric): 0.75 quantile forecast value 

quantile_0.975 (numeric): 0.975 quantile forecast value 

quantile_0.025_rounded (numeric): 0.025 quantile forecast value, rounded up to the nearest integer 

(Ex: 923 

quantile_0.25_rounded (numeric): 0.25 quantile forecast value, rounded up to the nearest integer 

quantile_0.5_rounded (numeric): 0.5 quantile forecast value, rounded up to the nearest integer 

quantile_0.75_rounded (numeric): 0.75 quantile forecast value, rounded up to the nearest integer 

quantile_0.975_rounded (numeric): 0.975 quantile forecast value, rounded up to the nearest integer 

forecast_teams (string): name of the team that generated the model; pulled from model metadata 

(Ex: CEPH Lab at Indiana University 

forecast_fullnames (string): full name of the model; pulled from model metadata 

(Ex: Rtrend COVID 

__Truth Data__ (`truth_data.csv`) 

_Contains the most recent observed COVID or flu hospitalization data for all states (including US, DC and Puerto Rico)._


week_ending_date(date): week ending date of observed data per row 
(Ex: 2024-11-16 

location (string): two-digit FIPS code associated with each state 

(Ex: 06 

location_name (string): spelled out state name (note: US is not spelled out) 

(Ex: California, US 
value (numeric): number of hospital admissions; should be an integer 
(Ex: 3 