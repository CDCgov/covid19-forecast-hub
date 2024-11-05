# COVID-19 Forecast Hub
This repository is designed to collect forecast data for the COVID-19 Forecast Hub run by the US CDC. The project collects forecast for the weekly new hospitalizations due to COVID-19. If you are interested in using these data for additional research or publications, please contact [covidhub@cdc.gov](mailto:covidhub@cdc.gov) for information regarding attribution of the source forecasts.


## Nowcasts and Forecasts of Confirmed Covid 19 Hospitalizations 
During the submission period, participating teams will be invited to submit national- and jurisdiction-specific (all 50 states, Washington DC, and Puerto Rico) probabilistic nowcasts and forecasts of the weekly number of confirmed COVID-19 hospital admissions during the preceding [epidemiological week ("epiweek")](https://epiweeks.readthedocs.io/en/stable/background.html), the current epiweek, and the following three epiweeks.

These weekly total COVID-19 admissions data will be sourced from the public releases of National Healthcare Safety Network (NHSN) data on [`data.cdc.gov`](https://data.cdc.gov). For more details on this dataset, its release schedule, and its schema, see the [NHSN Hospital Respiratory Data page](https://www.cdc.gov/nhsn/psc/hospital-respiratory-reporting.html).

## Dates and Deadlines 
The Challenge Period is tentatively scheduled to begin with the epiweek of Sunday, November 17, 2024 with the first Forecast Due Date of November 20, 2024.

Participants will be asked to submit nowcasts and forecasts by 11PM USA Eastern Time each Wednesday (the "Forecast Due Date"). If it becomes necessary to change the Forecast Due Date or time deadline, CovidHub will notify participants at least one week in advance. 

Weekly submissions (including file names) will be specified in terms of a "reference date": the Saturday following the Forecast Due Date. This is the last day of the USA/CDC epiweek (Sunday to Saturday) that contains the Forecast Due Date.

## Prediction Targets and Horizons

Participating teams will be able to submit national- and jurisdiction-specific (all 50 states, Washington DC, and Puerto Rico) predictions for two targets.

### Targets 
   1. Quantile predictions for epiweekly total laboratory-confirmed COVID-19 hospital admissions. This target is mandatory for any submitted location and forecast horizon.
   2. Individual forecast trajectories for epiweekly total laboratory-confirmed COVID-19 hospitalizations over time (i.e sampled trajectories). This target is optional for any submitted location.

Teams are encouraged but not required to submit forecasts for all weekly horizons or for all locations. 

### Horizons 

Teams can submit nowcasts or forecasts for these targets for the following temporal "horizons":

- `horizon = -1`: the epiweek preceding the reference date
- `horizon = 0`: the current epiweek
- `horizon = 1, 2, 3`: each of the three upcoming epiweeks

### Target data source
As noted above, the source of this target data (epiweekly total admissions) will be NHSN; see the [NHSN Hospital Respiratory Reporting](https://www.cdc.gov/nhsn/psc/hospital-respiratory-reporting.html) page for data details. This dataset will also serve as the source of "truth data" for retrospective forecast evaluation.

### Epiweeks

We use epiweeks as defined by the [US CDC](https://wwwn.cdc.gov/nndss/document/MMWR_Week_overview.pdf), which run Sunday through Saturday. The `target_end_date` for a prediction is the Saturday that ends the epiweek of interest. That is:

```python
target_end_date = reference_date + (horizon * 7)
```

Standard software packages for R and Python can help you convert from dates to epiweeks and vice versa:
#### R
- [`lubridate`](https://lubridate.tidyverse.org/reference/week.html)
- [`MMWRweek`](https://cran.r-project.org/web/packages/MMWRweek/)
#### Python
- [`epiweeks`](https://pypi.org/project/epiweeks/)
- [`pymmwr`](https://pypi.org/project/pymmwr/) 

## Further submission information

Detailed guidelines for formatting and submitting forecasts are available in the [`model-output` directory README](model-output/README.md). Detailed guidelines for formatting and submitting model metadata can be found in the [`model-metadata` directory README](model-metadata/README.md).

## Suggested workflow for first time submitters
First-time pull requests (PRs) into the Hub repository must be reviewed and merged manually; subsequent ones can be merged automatically if they pass appropriate checks. 

 We suggest that teams submitting for the first time make a PR adding their model metadata file to the [`model-metadata` directory](model-metadata) by 4 PM USA Eastern Time on the Wednesday they plan to submit their first forecast. This will allow subsequent PRs that submit forecasts to be merged automatically, provided checks pass.

## Alignment between CovidHub and FluSight

We have made changes from previous versions of the [COVID-19 Forecast Hub](https://github.com/reichlab/covid19-forecast-hub) challenges to align COVID-19 forecasting challenges with influenza forecasting run via the [Flusight Forecast Hub](https://github.com/cdcepi/FluSight-forecast-hub). 

Both Hubs will require quantile-based forecasts of epiweekly incident hospital admissions reported into NHSN, with the same -1:3 week horizon span. Both will accept these forecasts via Github pull requests of files formatted according to the standard [hubverse schema](https://hubverse.io/en/latest/user-guide/model-output.html#model-output). The Hubs also plan to share a forecast deadline of 11pm USA/Eastern time on Wednesdays.


## Acknowledgments
This repository follows the guidelines and standards outlined by the [hubverse](https://hubdocs.readthedocs.io/en/latest/), which provides a set of data formats and open source tools for modeling hubs. 

