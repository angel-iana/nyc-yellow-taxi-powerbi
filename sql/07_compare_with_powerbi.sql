/* 07 - Compare SQL with Power BI */
USE NYCTaxi;
GO

/* ---------- Part A: structure checks ---------- */

-- A1. Rows before any filter (expected 898131 = Power BI before exclusions)
SELECT COUNT(*) AS trips FROM core.trips;
-- Result: trips 898131

-- A2. Trips per vendor, empty VendorID shown as 3 like in Power Query
--     (expected 1 = 326613, 2 = 461910, 3 = 109608)
SELECT ISNULL(vendor_id, 3) AS vendor_id, COUNT(*) AS trips
FROM core.trips
GROUP BY ISNULL(vendor_id, 3)
ORDER BY vendor_id;
-- Result: 1 = 326613, 2 = 461910, 3 = 109608

-- A3. Vehicle type, all rows (expected Private 734499, Unknown 132520,
--     Medium Car 31107, Big Car 5)
SELECT vehicle_type, COUNT(*) AS trips
FROM core.trips
GROUP BY vehicle_type
ORDER BY trips DESC;
-- Result: Private 734499, Unknown 132520, Medium Car 31107, Big Car 5

-- A4. Rows kept after the exclusion rules (expected 891523)
SELECT COUNT(*) AS kept_trips
FROM core.trips
WHERE exclude_reason IS NULL;
-- Result: kept_trips 891523

-- A. Conclusion: All structure checks match the expected values (898,131 rows;
--    vendor 1/2/3 = 326,613 / 461,910 / 109,608; vehicle types as in 06; 891,523 kept).
--    SQL and the source files agree; these numbers are the reference for Power BI.

/* ---------- Part B: business questions (compare with your Power BI visuals) ---------- */

-- B1. Q1 - vehicle types by weekday (matrix: weekday x vehicle_type)
SELECT weekday_num, weekday_name, vehicle_type, COUNT(*) AS trips
FROM core.trips
WHERE exclude_reason IS NULL
GROUP BY weekday_num, weekday_name, vehicle_type
ORDER BY weekday_num, trips DESC;
-- Result:
/*
weekday_num	weekday_name	vehicle_type	trips
1	Monday	Private	114745
1	Monday	Unknown	19481
1	Monday	Medium Car	5031
2	Tuesday	Private	123295
2	Tuesday	Unknown	21263
2	Tuesday	Medium Car	5232
3	Wednesday	Private	104951
3	Wednesday	Unknown	19584
3	Wednesday	Medium Car	4344
3	Wednesday	Big Car	1
4	Thursday	Private	106118
4	Thursday	Unknown	19758
4	Thursday	Medium Car	4505
4	Thursday	Big Car	1
5	Friday	Private	123475
5	Friday	Unknown	24080
5	Friday	Medium Car	5251
6	Saturday	Private	84826
6	Saturday	Unknown	15500
6	Saturday	Medium Car	3737
6	Saturday	Big Car	1
7	Sunday	Private	71363
7	Sunday	Unknown	12269
7	Sunday	Medium Car	2711
7	Sunday	Big Car	1
*/

    -- B1b. Vehicle type as a percentage of each weekday's trips
    SELECT weekday_num, weekday_name, vehicle_type,
           COUNT(*) AS trips,
           CAST(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (PARTITION BY weekday_num) AS decimal(5,2)) AS pct_of_day
    FROM core.trips
    WHERE exclude_reason IS NULL
    GROUP BY weekday_num, weekday_name, vehicle_type
    ORDER BY pct_of_day DESC;
    -- Result:
    /*
    weekday_num	weekday_name	vehicle_type	trips	pct_of_day
    7	Sunday	Private	71363	82.65
    1	Monday	Private	114745	82.40
    2	Tuesday	Private	123295	82.31
    6	Saturday	Private	84826	81.51
    3	Wednesday	Private	104951	81.43
    4	Thursday	Private	106118	81.39
    5	Friday	Private	123475	80.81
    5	Friday	Unknown	24080	15.76
    3	Wednesday	Unknown	19584	15.20
    4	Thursday	Unknown	19758	15.15
    6	Saturday	Unknown	15500	14.89
    7	Sunday	Unknown	12269	14.21
    2	Tuesday	Unknown	21263	14.20
    1	Monday	Unknown	19481	13.99
    1	Monday	Medium Car	5031	3.61
    6	Saturday	Medium Car	3737	3.59
    2	Tuesday	Medium Car	5232	3.49
    4	Thursday	Medium Car	4505	3.46
    5	Friday	Medium Car	5251	3.44
    3	Wednesday	Medium Car	4344	3.37
    7	Sunday	Medium Car	2711	3.14
    6	Saturday	Big Car	1	0.00
    7	Sunday	Big Car	1	0.00
    4	Thursday	Big Car	1	0.00
    3	Wednesday	Big Car	1	0.00
    */

    -- B1c. Busiest weekdays: share of all kept trips
    SELECT weekday_num, weekday_name,
           COUNT(*) AS trips,
           CAST(100.0 * COUNT(*) / SUM(COUNT(*)) OVER () AS decimal(5,2)) AS pct_of_trips
    FROM core.trips
    WHERE exclude_reason IS NULL
    GROUP BY weekday_num, weekday_name
    ORDER BY pct_of_trips DESC;
    -- Result:
    /*
    weekday_num	weekday_name	trips	pct_of_trips
    5	Friday	152806	17.14
    2	Tuesday	149790	16.80
    1	Monday	139257	15.62
    4	Thursday	130382	14.62
    3	Wednesday	128880	14.46
    6	Saturday	104064	11.67
    7	Sunday	86344	9.68
    */

    -- B1d. Number of days per weekday and average trips per day
    SELECT weekday_num, weekday_name,
           COUNT(*)                    AS trips,
           COUNT(DISTINCT pickup_date) AS days,
           CAST(COUNT(*) * 1.0 / COUNT(DISTINCT pickup_date) AS decimal(10,1)) AS trips_per_day
    FROM core.trips
    WHERE exclude_reason IS NULL
    GROUP BY weekday_num, weekday_name
    ORDER BY trips_per_day DESC;
    -- Result: 
    /*
    weekday_num	weekday_name	trips	days	trips_per_day
    5	Friday	152806	9	16978.4
    2	Tuesday	149790	9	16643.3
    4	Thursday	130382	8	16297.8
    3	Wednesday	128880	8	16110.0
    1	Monday	139257	9	15473.0
    6	Saturday	104064	9	11562.7
    7	Sunday	86344	9	9593.8
    */

-- B1. Conclusion: On every weekday Private cars are 80.8–82.7% of trips, Unknown 14.0–15.8%,
--     Medium Car 3.1–3.6%; Big Car appears only 4 times. Wednesday and Thursday have 8 days
--     in the period, the other weekdays 9, so weekdays are compared per day: Friday (16,978)
--     and Tuesday (16,643) are the busiest, Sunday (9,594) the quietest.

-- B2. Q2 - top 5 pickup hours, average trips per day
SELECT TOP 5
       pickup_hour,
       COUNT(*) AS trips,
       COUNT(DISTINCT pickup_date) AS days,
       CAST(COUNT(*) * 1.0 / COUNT(DISTINCT pickup_date) AS decimal(10,1)) AS avg_trips_per_day
FROM core.trips
WHERE exclude_reason IS NULL
GROUP BY pickup_hour
ORDER BY avg_trips_per_day DESC;
-- Result:
/*
pickup_hour	trips	days	avg_trips_per_day
15	65686	61	1076.8
14	63787	61	1045.7
16	62879	61	1030.8
13	61974	61	1016.0
17	61587	61	1009.6
*/

    -- B2b. Share of trips per hour
    SELECT pickup_hour,
           CAST(COUNT(*) * 1.0 / COUNT(DISTINCT pickup_date) AS decimal(10,1)) AS avg_per_day,
           CAST(100.0 * COUNT(*) / SUM(COUNT(*)) OVER () AS decimal(5,2))       AS pct_of_trips
    FROM core.trips
    WHERE exclude_reason IS NULL
    GROUP BY pickup_hour
    ORDER BY pct_of_trips DESC;
    -- Result:
    /*
    pickup_hour	avg_per_day	pct_of_trips
    15	1076.8	7.37
    14	1045.7	7.15
    16	1030.8	7.05
    13	1016.0	6.95
    17	1009.6	6.91
    12	968.7	6.63
    11	888.4	6.08
    18	882.1	6.04
    10	818.7	5.60
    9	745.1	5.10
    19	712.7	4.88
    8	707.9	4.84
    7	610.1	4.17
    20	511.7	3.50
    6	449.6	3.08
    21	393.0	2.69
    22	345.8	2.37
    23	344.5	2.36
    0	223.0	1.53
    5	202.5	1.39
    4	193.3	1.32
    1	171.2	1.17
    3	134.0	0.92
    2	133.9	0.92
    */

    -- B2c. Share of the 13:00–17:00 window
    SELECT CAST(100.0 * SUM(CASE WHEN pickup_hour BETWEEN 13 AND 17 THEN 1 ELSE 0 END)
                / COUNT(*) AS decimal(5,2)) AS pct_13_to_17
    FROM core.trips
    WHERE exclude_reason IS NULL;
    -- Result: 
    /*pct_13_to_17
35.44*/

-- B2. Conclusion: The top 5 pickup hours are 13:00–17:00 and together hold 35.4% of trips;
--     15:00 peaks with 1,076.8 trips per day (7.4%). Morning hours 07:00–09:00 hold only
--     4.2–5.1% each – no morning rush, which fits the lockdown period.

-- B3. Q3 - average driver income per trip by weekday (fare + extra + tip)
SELECT weekday_num, weekday_name,
       CAST(SUM(driver_income) / COUNT(*) AS decimal(10,2)) AS avg_income_per_trip
FROM core.trips
WHERE exclude_reason IS NULL
GROUP BY weekday_num, weekday_name
ORDER BY avg_income_per_trip DESC;
-- Result:
/*
weekday_num	weekday_name	avg_income_per_trip
7	Sunday	17.07
5	Friday	16.49
4	Thursday	16.33
6	Saturday	16.28
2	Tuesday	16.28
1	Monday	16.27
3	Wednesday	16.17
*/

    -- B3b. Gap between the highest and lowest average income per trip
    WITH d AS (
        SELECT weekday_name, SUM(driver_income) / COUNT(*) AS avg_income
        FROM core.trips
        WHERE exclude_reason IS NULL
        GROUP BY weekday_name
    )
    SELECT CAST(MAX(avg_income) AS decimal(10,2))                     AS highest,
           CAST(MIN(avg_income) AS decimal(10,2))                     AS lowest,
           CAST(MAX(avg_income) - MIN(avg_income) AS decimal(10,2))   AS gap,
           CAST(100.0 * (MAX(avg_income) - MIN(avg_income)) / MIN(avg_income) AS decimal(5,2)) AS gap_pct
    FROM d;
    -- Result:
    /*
    highest	lowest	gap	gap_pct
    17.07	16.17	0.90	5.54
    */

-- B3. Conclusion: Sunday ($17.07) and Friday ($16.49) have the highest average driver income
--     per trip. The gap between the best and worst day is $0.90 (5.5%).

-- B4. Q4 - tip per mile by vehicle type (ratio of sums, not average of ratios)
SELECT vehicle_type,
       SUM(tip_amount)    AS tips,
       SUM(trip_distance) AS miles,
       CAST(SUM(tip_amount) / NULLIF(SUM(trip_distance), 0) AS decimal(10,3)) AS tip_per_mile
FROM core.trips
WHERE exclude_reason IS NULL
GROUP BY vehicle_type
ORDER BY tip_per_mile DESC;
-- Result:
/*
vehicle_type	tips	miles	tip_per_mile
Medium Car	54783.31	88955.93	0.616
Private	1239320.08	2019997.67	0.614
Unknown	168558.20	1005402.96	0.168
Big Car	4.16	0.00	NULL
*/

    -- B4b. Average distance and share of trips with a recorded tip, by vehicle type
    SELECT vehicle_type,
           COUNT(*) AS trips,
           CAST(AVG(trip_distance) AS decimal(10,2)) AS avg_miles,
           CAST(100.0 * SUM(CASE WHEN tip_amount > 0 THEN 1 ELSE 0 END) / COUNT(*) AS decimal(5,2)) AS pct_with_tip,
           CAST(SUM(tip_amount) / NULLIF(SUM(trip_distance), 0) AS decimal(10,4)) AS tip_per_mile
    FROM core.trips
    WHERE exclude_reason IS NULL
    GROUP BY vehicle_type
    ORDER BY trips DESC;
    -- Result:
    /*
    vehicle_type	trips	avg_miles	pct_with_tip	tip_per_mile
    Private	728773	2.77	57.87	0.6135
    Unknown	131935	7.62	43.75	0.1677
    Medium Car	30811	2.89	60.12	0.6158
    Big Car	4	0.00	50.00	NULL
    */

-- B4. Conclusion: On all trips, Medium Car ($0.616/mi) and Private ($0.614/mi) seem to lead and
--     Unknown is much lower ($0.168/mi). But tips are recorded only for card payments (TLC data
--     dictionary). With card payments only (08, B4c), tip per mile is similar for every type:
--     Unknown $1.003, Private $0.944, Medium Car $0.925. Vehicle type has little effect on tips;
--     the low value for Unknown came from trips without card payments. Big Car cannot be
--     calculated: 4 trips with 0 miles.