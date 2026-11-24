# Hub configuration files

This folder contains configuration files for the Hub, following the recommended [Hub configuration files in our documentation](https://docs.hubverse.io/en/latest/user-guide/hub-config.html).

## Forecasting Submission Window Exceptions

Note that `tasks.json` has a second round block for reference dates whose normal Wednesday deadline needs to be exceeded (usually by a single day and due to a federal holiday). This block is identical to the standard round except that:

- `reference_date` lists only the excepted dates;
- `target_end_date` lists only the dates reachable from those reference dates
  at horizons -1 through 3, since no other value can be submitted to the round;
- `submissions_due.end` is later than the standard `-3`.

Every excepted date is also removed from the standard round's `reference_date` list, since otherwise it would match two rounds.
