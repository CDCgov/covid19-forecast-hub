# COVID-19 Forecast Hub
This repository is designed to collect forecast data for the COVID-19 Forecast Hub run by the US CDC. The project collects forecast for two datasets:

   1. weekly new hospitalizations due to COVID-19, and
   2. weekly incident percentage of emergency department visits due to COVID-19 (optional, beginning June 18, 2025).

If you are interested in using these data for additional research or publications, please contact [covidhub@cdc.gov](mailto:covidhub@cdc.gov) for information regarding attribution of the source forecasts.


## Nowcasts and Forecasts of Confirmed COVID-19 Hospital Admissions 
During the submission period, participating teams will be invited to submit national- and jurisdiction-specific (all 50 states, Washington DC, and Puerto Rico) probabilistic nowcasts and forecasts of the weekly number of confirmed COVID-19 hospital admissions during the preceding [epidemiological week ("epiweek")](https://epiweeks.readthedocs.io/en/stable/background.html), the current epiweek, and the following three epiweeks.

The weekly total COVID-19 admissions counts can be found in the`totalconfc19newadm` column of the [National Healthcare Safety Network](https://www.cdc.gov/nhsn/index.html) (NHSN) [Hospital Respiratory Data (HRD) dataset](https://www.cdc.gov/nhsn/psc/hospital-respiratory-reporting.html).

NHSN provides a preliminary release of each week's HRD data on Wednesdays [here](https://data.cdc.gov/Public-Health-Surveillance/Weekly-Hospital-Respiratory-Data-HRD-Metrics-by-Ju/mpgq-jmmr/about_data). Official weekly data is released on Fridays [here](https://data.cdc.gov/Public-Health-Surveillance/Weekly-Hospital-Respiratory-Data-HRD-Metrics-by-Ju/ua7e-t2fy/about_data). For more details on this dataset, its release schedule, and its schema, see the [NHSN Hospital Respiratory Data page](https://www.cdc.gov/nhsn/psc/hospital-respiratory-reporting.html).

## Nowcasts and Forecasts of Covid-19 Emergency Department Visits
Beginning June 18, 2025, the COVID-19 Forecast Hub will also accept probabilistic nowcasts and forecasts of the proportion of emergency department visits due to COVID-19. This new target represents COVID-19 as a proportion of emergency department (ED) visits, aggregated by epiweek (Sunday-Saturday) and jurisdiction (states, DC, United States). The numerator is the number of visits with a discharge diagnosis of COVID-19, and the denominator is total visits. This target is optional for any submitted location and forecast horizon.

The weekly percent of ED visits due to COVID-19 can be found in the `percent_visits_covid` column of the [National Syndromic Surveillance Program](https://www.cdc.gov/nssp/index.html) (NSSP) [Emergency Department Visits - COVID-19, Flu, RSV, Sub-state](https://data.cdc.gov/Public-Health-Surveillance/NSSP-Emergency-Department-Visit-Trajectories-by-St/rdmq-nq56/about_data) dataset. Although these numbers are reported in the percentage form, we will accept forecasts as decimal proportions (i.e., `percent_visits_covid / 100`). To obtain state-level data, we filter the dataset to include only the rows where the `county` column is equal to `All`. 

We are working to make the Wednesday release of this dataset available on data.cdc.gov.  Until then, we will update the dataset every Wednesday in the [`auxiliary-data/nssp-raw-data`](auxiliary-data/nssp-raw-data) directory of our GitHub repository as a file named [`latest.csv`](auxiliary-data/nssp-raw-data/latest.csv).
These Wednesday data update contain the same data that are published on Fridays at [NSSP Emergency Department Visit trajectories](https://data.cdc.gov/Public-Health-Surveillance/NSSP-Emergency-Department-Visit-Trajectories-by-St/rdmq-nq56/about_data) and underlie the percentage ED visit reported on the PRISM Data Channel's [Respiratory Activity Levels page](https://www.cdc.gov/respiratory-viruses/data/activity-levels.html), which is also refreshed every Friday. The data represent the information available as of Wednesday morning through the previous Saturday. For example, the most recent data available on the 2025-06-11 release will be for the week ending 2025-06-07.

## Dates and Deadlines 
The Challenge Period is rolling.

Participants will be asked to submit nowcasts and forecasts by 11PM USA Eastern Time each Wednesday (the "Forecast Due Date"). If it becomes necessary to change the Forecast Due Date or time deadline, CovidHub will notify participants at least one week in advance. 

Weekly submissions (including file names) will be specified in terms of a "reference date": the Saturday following the Forecast Due Date. This is the last day of the USA/CDC epiweek (Sunday to Saturday) that contains the Forecast Due Date.

## Prediction Targets and Horizons

Participating teams will be able to submit national- and jurisdiction-specific (all 50 states, Washington DC, and Puerto Rico) predictions for following targets.

### Targets 
   1. Quantile predictions for epiweekly total laboratory-confirmed COVID-19 hospital admissions. 
   2. Individual forecast trajectories for epiweekly total laboratory-confirmed COVID-19 hospitalizations over time (i.e sampled trajectories). 
   3. Quantile predictions for epiweekly percent of emergency department visits due to COVID-19. 
   4. Individual forecast trajectories for epiweekly percent of emergency department visits due to COVID-19 over time (i.e sampled trajectories). 

Targets 2, 3 and 4 are optional for any submitted location whereas target 1 (quantile predictions for epiweekly COVID-19 hospital admissions) is mandatory for any submitted location and forecast horizon. Teams are encouraged but not required to submit forecasts for all weekly horizons or for all locations. 

### Horizons 

Teams can submit nowcasts or forecasts for these targets for the following temporal "horizons":

- `horizon = -1`: the epiweek preceding the reference date
- `horizon = 0`: the current epiweek
- `horizon = 1, 2, 3`: each of the three upcoming epiweeks

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

We suggest that teams submitting for the first time make a PR adding their model metadata file to the [`model-metadata` directory](model-metadata) by 4 PM USA Eastern Time on the Wednesday they plan to submit their first forecast. This will allow subsequent PRs that submit forecasts to be merged automatically, provided checks pass. We also request that teams sync their PR branch with the `main` branch using the `Update branch` button if their PR is behind the `main` branch, to ensure the automerge action runs smoothly.

## Alignment between CovidHub and FluSight

We have made changes from previous versions of the [COVID-19 Forecast Hub](https://github.com/reichlab/covid19-forecast-hub) challenges to align COVID-19 forecasting challenges with influenza forecasting run via the [Flusight Forecast Hub](https://github.com/cdcepi/FluSight-forecast-hub). 

Both Hubs will require quantile-based forecasts of epiweekly incident hospital admissions reported into NHSN, with the same -1:3 week horizon span. Both will accept these forecasts via Github pull requests of files formatted according to the standard [hubverse schema](https://hubverse.io/en/latest/user-guide/model-output.html#model-output). The Hubs also plan to share a forecast deadline of 11pm USA/Eastern time on Wednesdays.


## Acknowledgments
This repository follows the guidelines and standards outlined by the [hubverse](https://hubdocs.readthedocs.io/en/latest/), which provides a set of data formats and open source tools for modeling hubs. 

<details markdown=1>

<summary> CDC GitHub Guidelines </summary>

<br>


**General Disclaimer** This repository was created for use by CDC programs to collaborate on public health related projects in support of the [CDC mission](https://www.cdc.gov/about/cdc/#cdc_about_cio_mission-our-mission).  GitHub is not hosted by the CDC, but is a third party website used by CDC and its partners to share information and collaborate on software. CDC use of GitHub does not imply an endorsement of any one particular service, product, or enterprise.

## Related Documents

* [Open Practices](open_practices.md)
* [Rules of Behavior](rules_of_behavior.md)
* [Disclaimer](DISCLAIMER.md)
* [Contribution Notice](CONTRIBUTING.md)
* [Code of Conduct](code-of-conduct.md)


## Public Domain Standard Notice

This repository constitutes a work of the United States Government and is not subject to domestic copyright protection under 17 USC § 105. This repository is in the public domain within the United States, and copyright and related rights in the work worldwide are waived through the [CC0 1.0 Universal public domain dedication](https://creativecommons.org/publicdomain/zero/1.0/). All contributions to this repository will be released under the CC0 dedication. By submitting a pull request you are agreeing to comply with this waiver of copyright interest.

## License Standard Notice

The repository utilizes code licensed under the terms of the Apache Software License and therefore is licensed under ASL v2 or later.

This source code in this repository is free: you can redistribute it and/or modify it under the terms of the Apache Software License version 2, or (at your option) any later version.

This source code in this repository is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the Apache Software License for more details.

The source code forked from other open source projects will inherit its license.

## Privacy Standard Notice

This repository contains only non-sensitive, publicly available data and information. All material and community participation is covered by the [Disclaimer](DISCLAIMER.md) and [Code of Conduct](code-of-conduct.md). For more information about CDC's privacy policy, please visit [http://www.cdc.gov/other/privacy.html](https://www.cdc.gov/other/privacy.html).

## Contributing Standard Notice

Anyone is encouraged to contribute to the repository by [forking](https://help.github.com/articles/fork-a-repo) and submitting a pull request. (If you are new to GitHub, you might start with a [basic tutorial](https://help.github.com/articles/set-up-git).) By contributing to this project, you grant a world-wide, royalty-free, perpetual, irrevocable, non-exclusive, transferable license to all users under the terms of the [Apache Software License v2](http://www.apache.org/licenses/LICENSE-2.0.html) or later.

All comments, messages, pull requests, and other submissions received through CDC including this GitHub page may be subject to applicable federal law, including but not limited to the Federal Records Act, and may be archived. Learn more at [http://www.cdc.gov/other/privacy.html](http://www.cdc.gov/other/privacy.html).

## Records Management Standard Notice

This repository is not a source of government records, but is a copy to increase collaboration and collaborative potential. All government records will be published through the [CDC web site](http://www.cdc.gov).

</details>
