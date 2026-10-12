# NYC Yellow Taxi – Power BI analysis

Analysis of New York City yellow taxi trips from May–June 2020, from two
perspectives:

- **Vendor** – where and when trips happen across the city
- **Driver** – which days, hours and vehicles earn the most

Final project of the Power BI unit in the Data Analyst program at NewTech
Academy.

## Business questions

| Perspective | Question | Answer |
|-------------|----------|--------|
| Vendor | How are vehicle types distributed across the days of the week? | _to do_ |
| Vendor | Which five hours of the day have the most trip starts, on average? | _to do_ |
| Vendor | _Own question – to be confirmed_ | _to do_ |
| Driver | Which two weekdays have the highest average income per trip? | _to do_ |
| Driver | Which vehicle type gets the highest tip per mile? | _to do_ |
| Driver | _Own question – to be confirmed_ | _to do_ |

## Data

NYC Taxi & Limousine Commission (TLC) yellow taxi trip records, provided by
NewTech Academy: 898,131 trips in two monthly files, plus a lookup of 265
taxi zones. The files are not stored in this repository. Column meanings are
in [docs/data-dictionary.md](docs/data-dictionary.md).

May–June 2020 was the COVID-19 lockdown period in New York, with about
14,600 trips per day.

### Data quality

Before building the report, the files were loaded into SQL Server and
checked independently of Power BI.

| Finding | Trips | Share |
|---------|------:|------:|
| No vendor, passenger, rate code or payment data | 109,608 | 12.2% |
| Distance of 0 miles | 27,662 | 3.1% |
| 0 passengers | 22,912 | 2.6% |
| Impossible values (negative fare, duration ≤ 0 or > 5 h, distance > 200 mi, fare > $1,000, date outside May–June) | 6,608 | 0.7% |

Proposed handling: exclude the 6,608 trips with impossible values and keep
the rest, with missing values shown as *Unknown*. Excluded rows are flagged,
not deleted, so every decision stays visible. The handling of the extreme
values is waiting for confirmation from the course trainer.

## Repository structure

```
nyc-yellow-taxi-powerbi/
├── README.md
├── sql/             data checks in SQL Server (scripts only, no data)
├── report/          Power BI file
├── presentation/    slides with answers and recommendations
├── images/          screenshots used in this README
└── docs/            data dictionary
```

## How this project was built

The project was built with an AI assistant (Claude, by Anthropic) used as a
step-by-step guide and reviewer.

| Part | Angel Iana | AI assistant |
|------|-----------|--------------|
| Project decisions | Chose to check the data in SQL first and keep Power BI as the only report source; decided to escalate extreme values to the trainer | Proposed the cleaning rules and thresholds |
| SQL | Ran every script in SSMS, checked each result against the expected value, wrote the results and conclusions | Wrote the scripts and the expected values |
| Power BI | Built the data import and transformations in Power Query | Reviewed the .pbix file and listed corrections |
| Documentation | Reviewed and approved all text | Drafted the README, data dictionary and data quality report |
| Version control | All commits and pushes | Step-by-step instructions |

Every number in this repository comes from queries run by Angel Iana on the
original files.

## Tools

Power BI Desktop · Power Query (M) · DAX · SQL Server (data checks)
