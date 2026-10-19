NYC Yellow Taxi – Power BI analysis
Analysis of 898,131 New York City yellow taxi trips from May–June 2020, from two
perspectives:
Vendor – where and when trips happen across the city
Driver – which days, hours and places earn the most
All records are kept, as required by the project brief. The report also shows
the same pages without the 6,608 records with extreme values, and a page that
compares the two.
Every number below comes from a SQL Server query and matches the Power BI report.
![Comparison page: all records vs extreme values excluded](images/C/comparison.png)
Three views in one report
View	Records	Report pages	Purpose
A – All records	898,131	Vendor · Driver · Zones	Main answers, as required by the project brief
B – Extremes excluded	891,523	Vendor (excl.) · Driver (excl.) · Zones (excl.)	Same pages without the 6,608 records with impossible values
C – Comparison	both	Comparison	Which answers change when the extreme values are kept, and why
All three views use one Power BI file and one data model. View B is a page
filter on a Data Quality Flag column; no rows are deleted.
How to open the files
File	What it is	How to open
Power BI report	7 report pages (views A, B, C) plus check pages	Click Download raw file, open in Power BI Desktop
Presentation, view B (PDF)	10 slides with answers and recommendations, extremes excluded	Opens directly on GitHub
Presentation, view B (PowerPoint)	Same slides, with speaker notes	Click Download raw file, open in PowerPoint
SQL scripts	Data checks and the queries behind every number	Open in SSMS or read on GitHub
Key findings (view A, all records)
Perspective	Question	Answer
Vendor	How are vehicle types distributed across the days of the week?	The mix is almost the same every day: Private vehicles make 80.8–82.7% of trips. Per day, Friday (17,099.7 trips) and Tuesday (16,761.6) are the busiest and Sunday (9,672.2) the quietest.
Vendor	Which five hours of the day have the most trip starts, on average?	13:00–17:00, which together hold 35.44% of trips. 15:00 peaks with 1,085.2 trips per day.
Vendor	Which boroughs and zones generate the most trips, and how much do the airports contribute?	Manhattan has 86.33% of pickups, and the top 10 zones have 35.11% (Kips Bay leads with 35,327). Airports are only 2.71% of pickups, but a JFK pickup earns the driver $48.15 on average, compared with $16.76 for all trips.
Driver	Which two weekdays have the highest average income per trip?	Monday ($19.21) and Sunday ($16.93). Monday leads because of one record: a $429,562.25 trip with 0 miles and payment type "no charge". Without it, Monday's average is $16.15, and Sunday and Friday lead.
Driver	Which vehicle type gets the highest tip per mile?	Tips per mile are similar for every type once only card payments are counted: Unknown $1.002, Private $0.943, Medium Car $0.924. See the note below.
Driver	At which hours of the day does a driver earn the most per minute of trip time?	The afternoon pays least: 13:00–17:00 earns $1.061 per minute, compared with $1.358 for the other hours. 20:00 is the best hour ($2.227). 04:00 is negative (−$1.794) because one record has a duration of −531,231 minutes.
Why the tip answer changed
On all payment types, Unknown vehicles seemed to get much lower tips than the
other types. The TLC data dictionary states that `tip_amount` includes only card
tips, so cash tips are missing. With card payments only, the difference
disappears. The first result came from payment type, not vehicle type.
Zones in detail (pickups, view A)
Borough	Pickups	Avg income per trip
Manhattan	775,335	$14.62
Queens	54,457	$33.44
Brooklyn	37,177	$28.43
Bronx	21,821	$27.35
Staten Island	884	$65.29
EWR (Newark)	38	$69.25
Trips with an unknown zone (8,419) are not shown. Manhattan has the volume;
trips from the outer boroughs pay more per trip. JFK has 12,844 pickups at
$48.15 per trip.
How excluding extreme values changes the answers (view C)
Indicator	All records	Extremes excluded	Δ%
Trips per day	14,723.5	14,615.1	+0.7%
Farebox per day	$257,472.94	$250,330.28	+2.9%
Avg minutes per trip	13.46	12.23	+10.1%

Avg income per trip	$16.76	$16.38	+2.3%
Income per minute	$1.245	$1.339	−7.1%
Avg speed (mph)	25.60	17.13	+49.4%
Tip per mile (card)	$0.944	$0.945	−0.2%
Δ% = (All − Excluded) / Excluded.
Four of the six answers do not change. Busiest days, peak hours, tips per
mile and zones give the same result in both views.
Two answers change, each because of a single record:
Best income days: one $429,562.25 trip on Monday 4 May 2020, 20:00
(Lincoln Square East, 0 miles, 0.9 minutes, no charge) moves Monday to first
place. Without extremes, Sunday ($17.07) and Friday ($16.49) lead.
Income per minute by hour: one trip with a duration of −531,231 minutes
makes 04:00 negative, and the same $429,562.25 trip makes 20:00 the best hour.
Without extremes, 04:00 is the best hour ($1.722) and 15:00 the worst ($1.203).
Totals change little (+0.7% trips), but averages that divide by time or distance
move a lot: average speed rises by 49.4% because of trips with impossible
durations.
Data
NYC Taxi & Limousine Commission (TLC) yellow taxi trip records, provided by
NewTech Academy: 898,131 trips in two monthly files, plus a lookup of 265 taxi
zones. The raw CSV files are not stored in this repository; the Power BI file
contains the imported data. Column meanings are in
docs/data-dictionary.md.
Check against official figures. TLC reports about 898,127 trips for May and
June 2020. This matches the 898,131 rows loaded: 14,723.5 trips per day over
61 days.
May–June 2020 was the start of the recovery after the COVID-19 lockdown, so the
results describe that period and cannot be generalised to other years.
Industry indicators (TLC definitions), all records: 14,723.5 trips per day,
$257,472.94 farebox per day (without card tips), 13.46 minutes per trip, 63.02%
of trips with a known payment type paid by card.
Data quality
The files were loaded into SQL Server and checked independently of Power BI.
Finding	Trips	Share
No vendor, passenger, rate code or payment data	109,608	12.2%
Distance of 0 miles	27,662	3.1%
0 passengers	22,912	2.6%
Impossible values (see below)	6,608	0.74%
Records with impossible values are kept and labelled in a Data Quality Flag
column (one label per record, first rule that applies):
Flag	Rule	Records
negative_fare	fare below $0	4,062
duration_gt_300	trip longer than 5 hours	1,281
duration_le_0	duration of 0 minutes or less	1,211
distance_gt_200	distance above 200 miles	30
out_of_period	pickup date outside May–June 2020	23
fare_gt_1000	fare above $1,000	1
Missing values are shown as Unknown.
Limitations
The flag rules catch impossible values, not every suspicious one. A $950.00
trip of 0.3 miles and 0.7 minutes passes every rule.
The 23 out-of-period trips have no weekday in the 61-day calendar, so they are
in the totals but not in the weekday rows.
Averages are sensitive to single records: one trip changes two of the six answers.
Cash tips are not recorded, so tip results use card payments only.
Trip minutes cover pickup to drop-off; waiting time between trips is not in the data.
There is no vehicle or driver ID, so income per shift or per car cannot be calculated.
Report pages
Page	View	Content
Vendor	A	TLC indicators, trips per day by weekday and hour (heatmap), vehicle types by weekday
Driver	A	Income per trip by weekday, tip per mile by vehicle type, income per minute and speed by hour
Zones	A	Map of the 263 taxi zones with a metric selector (pickups, drop-offs, income per trip, income per minute) and a borough ▸ zone matrix
Vendor / Driver / Zones (excl.)	B	The same pages, filtered to records without extreme values
Comparison	C	Key indicators side by side with Δ%, income by weekday and by hour in both views, and the answer to each question
Checks	–	Each measure next to its SQL result
![Vendor page](images/A/vendor.png)
![Driver page](images/A/driver.png)
![Zones page](images/A/zones.png)
Walkthrough of the view B pages:
![Report walkthrough, view B](images/B/nyc-yellow-taxi-dashboard.gif)
Repository structure
```
nyc-yellow-taxi-powerbi/
├── README.md
├── sql/             data checks and answers in SQL Server (scripts only, no data)
├── report/          Power BI file (views A, B and C)
├── presentation/    slides with answers and recommendations, one folder per view
├── images/          screenshots used in this README, one folder per view (A, B, C)
└── docs/            data dictionary, taxi zone shapes (GeoJSON)
```
How this project was built
The project was built with an AI assistant (Claude, by Anthropic) used as a
step-by-step guide and reviewer.
Part	Angel Iana	AI assistant
Project decisions	Chose to check the data in SQL first and keep Power BI as the only report source; chose the two own questions (zones, income per minute); decided to keep all records and add the excluded and comparison views	Proposed the cleaning rules, the flag column and the three-view structure
Industry context	Selected which indicators to use	Researched TLC reports and indicator definitions online
SQL	Ran every script in SSMS, checked each result and approved the conclusions	Wrote the scripts and drafted the conclusions from the results
Power BI	Built the model, measures and all report pages, including the comparison page; checked every measure against SQL	Proposed DAX measures, page layouts and formatting; reviewed screenshots
Map	Converted the TLC zone shapefile to GeoJSON (mapshaper) and built the Azure Maps visual	Gave the conversion steps and checked the file
Presentation	Replaced the map images, adjusted the layout, checked every number and exported the final deck	Drafted the slide structure, text, speaker notes and a model deck
Documentation	Reviewed and approved all text	Drafted the README, data dictionary and data quality report
Version control	All commits and pushes	Step-by-step instructions
Tools
Power BI Desktop · Power Query (M) · DAX · Azure Maps · SQL Server · mapshaper
Sources
TLC – Yellow trip records data dictionary
TLC – Monthly indicators
TLC – Taxi zone shapefile