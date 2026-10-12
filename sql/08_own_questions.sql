/* 08 - Own questions (q5 Vendor, q6 Driver): explore in SQL before building in Power BI
   q5. Which boroughs and pickup zones generate the most trips, and how much do the airports contribute?
   q6. At which hours of the day does a driver earn the most per minute of trip time?
   All queries use only the kept trips (exclude_reason IS NULL, 891,523 trips).
*/
USE NYCTaxi;
GO

/* ---------- q5. Boroughs, zones and airports ---------- */

-- q5a. Trips by pickup borough, with share of all trips
SELECT ISNULL(z.borough, 'Not in lookup') AS borough,
       COUNT(*) AS trips,
       CAST(100.0 * COUNT(*) / SUM(COUNT(*)) OVER () AS decimal(5,2)) AS pct_of_trips
FROM core.trips AS t
LEFT JOIN core.zone AS z ON z.location_id = t.pu_location_id
WHERE t.exclude_reason IS NULL
GROUP BY ISNULL(z.borough, 'Not in lookup')
ORDER BY trips DESC;
-- Result: 
/*
borough	trips	pct_of_trips
Manhattan	770010	86.37
Queens	53869	6.04
Brooklyn	36891	4.14
Bronx	21679	2.43
Unknown	8178	0.92
Staten Island	860	0.10
EWR	36	0.00
*/

-- q5b. Top 10 pickup zones, with share and running share
WITH zones AS (
    SELECT z.borough, z.zone, COUNT(*) AS trips
    FROM core.trips AS t
    JOIN core.zone AS z ON z.location_id = t.pu_location_id
    WHERE t.exclude_reason IS NULL
    GROUP BY z.borough, z.zone
)
SELECT TOP 10
       RANK() OVER (ORDER BY trips DESC) AS rnk,
       borough, zone, trips,
       CAST(100.0 * trips / SUM(trips) OVER () AS decimal(5,2)) AS pct_of_trips,
       CAST(100.0 * SUM(trips) OVER (ORDER BY trips DESC ROWS UNBOUNDED PRECEDING)
            / SUM(trips) OVER () AS decimal(5,2))               AS running_pct
FROM zones
ORDER BY trips DESC;
-- Result: 
/*
rnk	borough	zone	trips	pct_of_trips	running_pct
1	Manhattan	Kips Bay	35081	3.93	3.93
2	Manhattan	Upper East Side North	34914	3.92	7.85
3	Manhattan	Upper East Side South	32493	3.64	11.50
4	Manhattan	Lenox Hill East	31777	3.56	15.06
5	Manhattan	Yorkville West	30978	3.47	18.53
6	Manhattan	Lenox Hill West	30488	3.42	21.95
7	Manhattan	Upper West Side North	30161	3.38	25.34
8	Manhattan	Penn Station/Madison Sq West	29938	3.36	28.70
9	Manhattan	East Harlem South	28840	3.23	31.93
10	Manhattan	Clinton East	28585	3.21	35.14
*/

-- q5c. Check which zones count as airports (expected: JFK Airport, LaGuardia Airport, Newark Airport)
SELECT location_id, borough, zone, service_zone
FROM core.zone
WHERE zone LIKE '%Airport%';
-- Result: 
/*
location_id	borough	zone	service_zone
1	EWR	Newark Airport	EWR
132	Queens	JFK Airport	Airports
138	Queens	LaGuardia Airport	Airports
*/

-- q5d. Airport share of pickups and of drop-offs
SELECT 'pickup' AS direction,
       SUM(CASE WHEN z.zone LIKE '%Airport%' THEN 1 ELSE 0 END) AS airport_trips,
       CAST(100.0 * SUM(CASE WHEN z.zone LIKE '%Airport%' THEN 1 ELSE 0 END) / COUNT(*) AS decimal(5,2)) AS pct_airport
FROM core.trips AS t
LEFT JOIN core.zone AS z ON z.location_id = t.pu_location_id
WHERE t.exclude_reason IS NULL
UNION ALL
SELECT 'dropoff',
       SUM(CASE WHEN z.zone LIKE '%Airport%' THEN 1 ELSE 0 END),
       CAST(100.0 * SUM(CASE WHEN z.zone LIKE '%Airport%' THEN 1 ELSE 0 END) / COUNT(*) AS decimal(5,2))
FROM core.trips AS t
LEFT JOIN core.zone AS z ON z.location_id = t.do_location_id
WHERE t.exclude_reason IS NULL;
-- Result:
/*
direction	airport_trips	pct_airport
pickup	24150	2.71
dropoff	5708	0.64
*/

-- q5e. Airport pickups by airport: trips, average distance, average driver income
SELECT z.zone,
       COUNT(*) AS trips,
       CAST(AVG(t.trip_distance) AS decimal(10,2))          AS avg_miles,
       CAST(SUM(t.driver_income) / COUNT(*) AS decimal(10,2)) AS avg_income_per_trip
FROM core.trips AS t
JOIN core.zone AS z ON z.location_id = t.pu_location_id
WHERE t.exclude_reason IS NULL
  AND z.zone LIKE '%Airport%'
GROUP BY z.zone
ORDER BY trips DESC;
-- Result: 
/*
zone	trips	avg_miles	avg_income_per_trip
JFK Airport	12720	14.41	48.20
LaGuardia Airport	11394	9.22	33.27
Newark Airport	36	3.41	74.86
*/

--q5f. AVG income for all trips 
   SELECT CAST(SUM(driver_income) / COUNT(*) AS decimal(10,2)) AS avg_income_all
   FROM core.trips WHERE exclude_reason IS NULL;
--Result:
/*
avg_income_all
16.38
*/

-- q5g. Newark check by rate code.

   SELECT t.ratecode_id, COUNT(*) AS trips, AVG(t.trip_distance) AS avg_miles
   FROM core.trips AS t
   WHERE t.exclude_reason IS NULL AND t.pu_location_id = 1
   GROUP BY t.ratecode_id;
--Result:
/*
ratecode_id	trips	avg_miles
NULL	1	15.020000
1	7	3.900000
3	4	19.687500
5	24	0.075416
*/

-- q5. Conclusion:
--     Manhattan holds 86.37% of all pickups (770,010 trips). The other boroughs are small:
--     Queens 6.04%, Brooklyn 4.14%, Bronx 2.43%, Staten Island 0.10%; 0.92% have an unknown zone.
--     All top 10 pickup zones are in Manhattan and together hold 35.14% of trips. Kips Bay leads
--     with 3.93%, and five of the ten are on the Upper East Side (Upper East Side North and South,
--     Lenox Hill East and West, Yorkville West).
--     Airports are a small share of trips but a large one per trip: 24,150 pickups (2.71%) and
--     5,708 drop-offs (0.64%). A JFK pickup brings $48.20 per trip on average (14.41 mi) and
--     LaGuardia $33.27 (9.22 mi), compared with $16.38 for all trips.
--     Newark has only 36 pickups, too few to draw a conclusion. Their average of 3.41 mi is pulled
--     down by 24 negotiated-fare trips (RatecodeID 5) with almost no recorded distance (0.08 mi on
--     average); the 4 trips at the Newark rate (RatecodeID 3) average 19.69 mi.


/* ---------- q6. Driver income per minute by hour ---------- */

-- q6a. Income per minute of trip time by pickup hour (ratio of sums, like Tip per Mile)
SELECT pickup_hour,
       COUNT(*) AS trips,
       CAST(SUM(duration_min) / COUNT(*) AS decimal(10,2))                    AS avg_minutes,
       CAST(SUM(driver_income) / COUNT(*) AS decimal(10,2))                   AS avg_income_per_trip,
       CAST(SUM(driver_income) / NULLIF(SUM(duration_min), 0) AS decimal(10,3)) AS income_per_minute
FROM core.trips
WHERE exclude_reason IS NULL
GROUP BY pickup_hour
ORDER BY pickup_hour;
-- Result: 
/*
pickup_hour	trips	avg_minutes	avg_income_per_trip	income_per_minute
0	13606	14.41	20.86	1.448
1	10443	17.73	27.34	1.542
2	8167	18.54	29.36	1.584
3	8171	20.29	33.68	1.660
4	11794	22.44	38.63	1.722
5	12351	13.93	21.65	1.554
6	27425	10.35	14.84	1.433
7	37215	10.92	14.75	1.351
8	43180	10.94	14.20	1.298
9	45453	10.66	13.74	1.289
10	49941	11.01	14.18	1.289
11	54195	11.27	14.31	1.270
12	59088	11.35	14.36	1.266
13	61974	11.37	14.15	1.245
14	63787	11.82	14.43	1.221
15	65686	12.91	15.52	1.203
16	62879	13.46	16.87	1.253
17	61587	12.62	16.69	1.322
18	53808	11.46	16.03	1.399
19	43474	11.34	16.17	1.426
20	31215	11.92	17.14	1.438
21	23974	12.35	17.83	1.444
22	21096	13.15	19.11	1.453
23	21014	14.66	20.66	1.409
*/

-- q6b. Top 5 and bottom 5 hours by income per minute
WITH h AS (
    SELECT pickup_hour,
           SUM(driver_income) / NULLIF(SUM(duration_min), 0) AS income_per_minute
    FROM core.trips
    WHERE exclude_reason IS NULL
    GROUP BY pickup_hour
)
SELECT pickup_hour,
       CAST(income_per_minute AS decimal(10,3))               AS income_per_minute,
       RANK() OVER (ORDER BY income_per_minute DESC)          AS rank_best
FROM h
ORDER BY income_per_minute DESC;
-- Result: 
/*
pickup_hour	income_per_minute	rank_best
4	1.722	1
3	1.660	2
2	1.584	3
5	1.554	4
1	1.542	5
22	1.453	6
0	1.448	7
21	1.444	8
20	1.438	9
6	1.433	10
19	1.426	11
23	1.409	12
18	1.399	13
7	1.351	14
17	1.322	15
8	1.298	16
9	1.289	17
10	1.289	18
11	1.270	19
12	1.266	20
16	1.253	21
13	1.245	22
14	1.221	23
15	1.203	24
*/

-- q6c. Does the busiest window (13:00-17:00) pay more or less per minute than the rest of the day?
SELECT CASE WHEN pickup_hour BETWEEN 13 AND 17 THEN '13:00-17:00' ELSE 'other hours' END AS time_window,
       COUNT(*) AS trips,
       CAST(SUM(driver_income) / NULLIF(SUM(duration_min), 0) AS decimal(10,3)) AS income_per_minute
FROM core.trips
WHERE exclude_reason IS NULL
GROUP BY CASE WHEN pickup_hour BETWEEN 13 AND 17 THEN '13:00-17:00' ELSE 'other hours' END;
-- Result: 
/*
time_window	trips	income_per_minute
13:00-17:00	315913	1.248
other hours	575610	1.390
*/

-- q6. Note: minutes are trip time only (pickup to drop-off); waiting time between trips is not in the data.
-- q6. Conclusion:
--     The best-paid hours per minute of trip time are at night: 04:00 ($1.722/min), 03:00 ($1.660),
--     02:00 ($1.584), 05:00 ($1.554) and 01:00 ($1.542). Night trips are also longer: at 04:00 a trip
--     lasts 22.44 min and brings $38.63 on average, but there are only 11,794 trips at that hour.
--     The busiest hours pay the least: 15:00 is the busiest hour and the lowest per minute ($1.203),
--     followed by 14:00 ($1.221) and 13:00 ($1.245). The 13:00-17:00 window brings $1.248/min,
--     compared with $1.390/min for all other hours.
--     For a driver the choice is between volume (many short trips in the afternoon) and value per
--     minute (fewer, longer trips at night). Waiting time between trips is not in the data, and at
--     night there are fewer passengers, so the real hourly earnings can be lower than these figures.
--     Query m2 checks whether traffic speed explains the low afternoon values.


/* ---------- Industry metrics (TLC Monthly Indicators) for the Vendor KPI row ---------- */

-- m1. TLC-style indicators for the kept trips
--     Farebox = fare + surcharges + taxes + tolls, without credit card tips (TLC definition)
SELECT CAST(COUNT(*) * 1.0 / COUNT(DISTINCT pickup_date) AS decimal(10,1))                       AS trips_per_day,
       CAST(SUM(total_amount - tip_amount) / COUNT(DISTINCT pickup_date) AS decimal(12,2))       AS farebox_per_day,
       CAST(AVG(duration_min) AS decimal(6,2))                                                  AS avg_minutes_per_trip,
       CAST(100.0 * SUM(CASE WHEN payment_type_id = 1 THEN 1 ELSE 0 END) / COUNT(*) AS decimal(5,2)) AS pct_card
FROM core.trips
WHERE exclude_reason IS NULL;
-- Result: 
/*
trips_per_day	farebox_per_day	avg_minutes_per_trip	pct_card
14615.1	250330.28	12.23	55.65
*/

-- m1b. Check: extreme or negative total_amount values that could distort farebox
SELECT MIN(total_amount) AS min_total, MAX(total_amount) AS max_total,
       SUM(CASE WHEN total_amount < 0 THEN 1 ELSE 0 END) AS negative_totals
FROM core.trips
WHERE exclude_reason IS NULL;
-- Result: 
/*
min_total	max_total	negative_totals
0.00	950.30	0
*/

-- m1c. Benchmark: TLC official figures for yellow taxi = 11,237 trips/day (May 2020), 18,326 (June 2020)
SELECT MONTH(pickup_date) AS month_no,
       COUNT(*) AS trips,
       COUNT(DISTINCT pickup_date) AS days,
       CAST(COUNT(*) * 1.0 / COUNT(DISTINCT pickup_date) AS decimal(10,1)) AS trips_per_day
FROM core.trips
WHERE exclude_reason IS NULL
GROUP BY MONTH(pickup_date)
ORDER BY month_no;
-- Result: 
/*
month_no	trips	days	trips_per_day
5	345750	31	11153.2
6	545773	30	18192.4
*/

-- m1d.  pct_card only for trips with known payment type
SELECT CAST(100.0 * SUM(CASE WHEN payment_type_id = 1 THEN 1 ELSE 0 END) / COUNT(*) AS decimal(5,2)) AS pct_card_known
FROM core.trips WHERE exclude_reason IS NULL AND payment_type_id IS NOT NULL;
-- Result:
/*pct_card_known
63.40*/

-- Conclusion:
-- m1. Conclusion: In the TLC Monthly Indicators format, the kept trips give 14,615.1 trips per day,
--     a farebox of $250,330.28 per day, 12.23 minutes per trip and 55.65% of trips paid by card
--     (63.40% of trips with a known payment type, see m1d).

-- m1b. Conclusion: total_amount has no negative values (min $0.00, max $950.30), so the farebox
--     is not distorted by negative amounts.

-- m1c. Conclusion: Kept trips per day are 11,153.2 in May and 18,192.4 in June. TLC's official
--     figures for yellow taxi are 11,237 (May 2020) and 18,326 (June 2020). Ours are slightly lower,
--     consistent with the 6,608 trips excluded for impossible values. June has clearly more trips
--     per day than May, as the city reopened.
-- m1d. Conclusion: Among trips with a known payment type, 63.40% are paid by card. The 55.65% in m1
--     is lower because it also counts the trips without payment data (109,608 in the raw files).


/* ---------- Driver: speed by hour (explains q6) ---------- */

-- m2. Average speed (mph) by pickup hour, ratio of sums
SELECT pickup_hour,
       CAST(SUM(trip_distance) / NULLIF(SUM(duration_min) / 60.0, 0) AS decimal(6,2)) AS avg_speed_mph
FROM core.trips
WHERE exclude_reason IS NULL
GROUP BY pickup_hour
ORDER BY pickup_hour;
-- Result: 
/*
pickup_hour	avg_speed_mph
0	22.17
1	23.01
2	24.45
3	26.37
4	29.22
5	26.07
6	20.46
7	17.88
8	15.88
9	14.75
10	15.04
11	14.71
12	14.53
13	14.26
14	14.19
15	14.71
16	15.12
17	15.75
18	16.83
19	18.06
20	18.88
21	19.53
22	21.25
23	22.74
*/

-- m3. Totals for the Driver KPI cards
SELECT CAST(SUM(driver_income) / SUM(duration_min) AS decimal(10,3))               AS income_per_minute,
       CAST(SUM(trip_distance) / (SUM(duration_min) / 60.0) AS decimal(6,2))        AS avg_speed_mph,
       CAST(SUM(CASE WHEN payment_type_id = 1 THEN tip_amount END)
          / SUM(CASE WHEN payment_type_id = 1 THEN trip_distance END) AS decimal(10,3)) AS tip_per_mile_card
FROM core.trips
WHERE exclude_reason IS NULL;

--Result:

/*
 income_per_minute	avg_speed_mph	tip_per_mile_card
1.339	17.13	0.945
*/

--Conclusion:
-- m2. Conclusion: Traffic is fastest at night (29.22 mph at 04:00, 26.37 at 03:00) and slowest
--     at midday and in the afternoon (14.19 mph at 14:00, 14.26 at 13:00). The hours with the lowest
--     speed are also the hours with the lowest income per minute (q6: 14:00 $1.221, 15:00 $1.203),
--     and the fastest hours pay the most (04:00 $1.722). Slow traffic explains the low afternoon values.
-- m3. Conclusion: For all kept trips, drivers earn $1.339 per minute of trip time, traffic moves
--     at 17.13 mph on average, and card payments bring $0.945 in tips per mile. These match the
--     Driver page KPI cards in Power BI.

/* ---------- Extra checks from the industry research ---------- */

-- B4c. Tip per mile by vehicle type, card payments only (cash tips are not recorded)
SELECT vehicle_type,
       COUNT(*) AS trips,
       CAST(SUM(tip_amount) / NULLIF(SUM(trip_distance), 0) AS decimal(10,3)) AS tip_per_mile
FROM core.trips
WHERE exclude_reason IS NULL
  AND payment_type_id = 1
GROUP BY vehicle_type
ORDER BY tip_per_mile DESC;
-- Result:
/*
vehicle_type	trips	tip_per_mile
Unknown	14084	1.003
Private	462404	0.944
Medium Car	19608	0.925
Big Car	4	NULL
*/

--Conclusion:
-- B4c. Conclusion: With card payments only, tip per mile is similar for all types: Unknown $1.003,
--     Private $0.944, Medium Car $0.925. The low value for Unknown in B4 ($0.168) came from trips
--     without card payments, whose tips are not recorded, not from smaller tips.


-- q5f. JFK flat fare trips (RatecodeID 2): count and average driver income
SELECT ratecode_id,
       COUNT(*) AS trips,
       CAST(SUM(driver_income) / COUNT(*) AS decimal(10,2)) AS avg_income_per_trip,
       CAST(AVG(duration_min) AS decimal(6,2))              AS avg_minutes
FROM core.trips
WHERE exclude_reason IS NULL
  AND ratecode_id = 2
GROUP BY ratecode_id;
-- Result: 
/*
ratecode_id	trips	avg_income_per_trip	avg_minutes
2	6693	61.29	27.81
*/

--Conclusion:
-- q5f. Conclusion: 6,693 trips used the JFK flat fare (RatecodeID 2). They bring $61.29 per trip
--     on average and last 27.81 minutes, compared with $16.38 and 12.23 minutes for all trips.
