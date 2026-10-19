/* 09 - All data vs extremes excluded
   View A (primary): all 898,131 trips, as required by the project brief.
   View B: 891,523 trips, the 6,608 trips with extreme values excluded (exclude_reason IS NULL).
   View C: the comparison. delta_pct = (all - excl) / excl * 100.
   "Answer changed" = a different order in the top list, or |delta_pct| >= 5.
   Days = 61 for both views: the calendar days of May-June 2020. Trips with a pickup date outside
   this period stay in the totals of view A, but do not add days to the denominator.
*/
USE NYCTaxi;
GO

/* ---------- c0. Record counts per view ---------- */

-- c0a. Trips in each view
SELECT COUNT(*)                                                   AS trips_all,
       SUM(CASE WHEN exclude_reason IS NULL THEN 1 ELSE 0 END)    AS trips_excl,
       SUM(CASE WHEN exclude_reason IS NOT NULL THEN 1 ELSE 0 END) AS trips_flagged,
       CAST(100.0 * SUM(CASE WHEN exclude_reason IS NOT NULL THEN 1 ELSE 0 END) / COUNT(*) AS decimal(5,2)) AS pct_flagged
FROM core.trips;
-- Result: 
--trips_all	trips_excl	trips_flagged	pct_flagged
--898131	891523	6608	0.74

-- c0b. Flagged trips by reason (these become the "Data Quality Flag" values in Power Query)
SELECT ISNULL(exclude_reason, 'OK') AS data_quality_flag, COUNT(*) AS trips
FROM core.trips
GROUP BY ISNULL(exclude_reason, 'OK')
ORDER BY trips DESC;
-- Result:
/*
data_quality_flag	trips
OK	891523
negative_fare	4062
duration_gt_300	1281
duration_le_0	1211
distance_gt_200	30
out_of_period	23
fare_gt_1000	1
*/


/* ---------- c1. Q1 - vehicle types by weekday ---------- */

-- c1a. Share of each vehicle type in each weekday's trips, all vs excl
WITH w AS (
    SELECT weekday_num, weekday_name, vehicle_type,
           COUNT(*)                                                AS trips_all,
           SUM(CASE WHEN exclude_reason IS NULL THEN 1 ELSE 0 END) AS trips_excl
    FROM core.trips
    GROUP BY weekday_num, weekday_name, vehicle_type
)
SELECT weekday_num, weekday_name, vehicle_type, trips_all, trips_excl,
       CAST(100.0 * trips_all  / SUM(trips_all)  OVER (PARTITION BY weekday_num) AS decimal(5,2)) AS pct_of_day_all,
       CAST(100.0 * trips_excl / SUM(trips_excl) OVER (PARTITION BY weekday_num) AS decimal(5,2)) AS pct_of_day_excl
FROM w
ORDER BY weekday_num, trips_all DESC;
-- Result:
/*
weekday_num	weekday_name	vehicle_type	trips_all	trips_excl	pct_of_day_all	pct_of_day_excl
1	Monday	Private	115640	114745	82.44	82.40
1	Monday	Unknown	19568	19481	13.95	13.99
1	Monday	Medium Car	5065	5031	3.61	3.61
2	Tuesday	Private	124222	123295	82.35	82.31
2	Tuesday	Unknown	21350	21263	14.15	14.20
2	Tuesday	Medium Car	5282	5232	3.50	3.49
3	Wednesday	Private	105766	104951	81.46	81.43
3	Wednesday	Unknown	19684	19584	15.16	15.20
3	Wednesday	Medium Car	4391	4344	3.38	3.37
3	Wednesday	Big Car	1	1	0.00	0.00
4	Thursday	Private	106952	106118	81.44	81.39
4	Thursday	Unknown	19839	19758	15.11	15.15
4	Thursday	Medium Car	4537	4505	3.45	3.46
4	Thursday	Big Car	1	1	0.00	0.00
5	Friday	Private	124398	123475	80.83	80.81
5	Friday	Unknown	24195	24080	15.72	15.76
5	Friday	Medium Car	5303	5251	3.45	3.44
5	Friday	Big Car	1	0	0.00	0.00
6	Saturday	Private	85525	84826	81.55	81.51
6	Saturday	Unknown	15559	15500	14.84	14.89
6	Saturday	Medium Car	3794	3737	3.62	3.59
6	Saturday	Big Car	1	1	0.00	0.00
7	Sunday	Private	71996	71363	82.70	82.65
7	Sunday	Unknown	12325	12269	14.16	14.21
7	Sunday	Medium Car	2735	2711	3.14	3.14
7	Sunday	Big Car	1	1	0.00	0.00
*/

-- c1b. Trips per day by weekday (calendar days of May-June), all vs excl, with rank
WITH cal AS (
    SELECT TOP 61 DATEADD(day, ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) - 1, CAST('2020-05-01' AS date)) AS d
    FROM sys.all_objects
), days AS (
    SELECT ((DATEPART(weekday, d) + @@DATEFIRST - 2) % 7) + 1 AS weekday_num, COUNT(*) AS days
    FROM cal GROUP BY ((DATEPART(weekday, d) + @@DATEFIRST - 2) % 7) + 1
), t AS (
    SELECT weekday_num, weekday_name,
           COUNT(*)                                                AS trips_all,
           SUM(CASE WHEN exclude_reason IS NULL THEN 1 ELSE 0 END) AS trips_excl
    FROM core.trips GROUP BY weekday_num, weekday_name
)
SELECT t.weekday_num, t.weekday_name, d.days,
       CAST(t.trips_all  * 1.0 / d.days AS decimal(10,1)) AS trips_per_day_all,
       CAST(t.trips_excl * 1.0 / d.days AS decimal(10,1)) AS trips_per_day_excl,
       RANK() OVER (ORDER BY t.trips_all  DESC) AS rank_all,
       RANK() OVER (ORDER BY t.trips_excl DESC) AS rank_excl
FROM t JOIN days d ON d.weekday_num = t.weekday_num
ORDER BY t.weekday_num;
-- Result: (check: days = 8 for Wednesday and Thursday, 9 for the other weekdays)
/*
weekday_num	weekday_name	days	trips_per_day_all	trips_per_day_excl	rank_all	rank_excl
1	Monday	9	15585.9	15473.0	3	3
2	Tuesday	9	16761.6	16643.3	2	2
3	Wednesday	8	16230.3	16110.0	5	5
4	Thursday	8	16416.1	16297.8	4	4
5	Friday	9	17099.7	16978.4	1	1
6	Saturday	9	11653.2	11562.7	6	6
7	Sunday	9	9673.0	9593.8	7	7
*/


/* ---------- c2. Q2 - top 5 pickup hours ---------- */

-- c2a. Average trips per day by pickup hour (61 days), all vs excl, with rank
WITH h AS (
    SELECT pickup_hour,
           COUNT(*)                                                AS trips_all,
           SUM(CASE WHEN exclude_reason IS NULL THEN 1 ELSE 0 END) AS trips_excl
    FROM core.trips GROUP BY pickup_hour
)
SELECT pickup_hour,
       CAST(trips_all  / 61.0 AS decimal(10,1)) AS trips_per_day_all,
       CAST(trips_excl / 61.0 AS decimal(10,1)) AS trips_per_day_excl,
       RANK() OVER (ORDER BY trips_all  DESC) AS rank_all,
       RANK() OVER (ORDER BY trips_excl DESC) AS rank_excl
FROM h
ORDER BY rank_all;
-- Result:
/*
pickup_hour	trips_per_day_all	trips_per_day_excl	rank_all	rank_excl
15	1085.2	1076.8	1	1
14	1053.6	1045.7	2	2
16	1038.1	1030.8	3	3
13	1024.2	1016.0	4	4
17	1016.5	1009.6	5	5
12	975.3	968.7	6	6
11	894.6	888.4	7	7
18	888.4	882.1	8	8
10	823.5	818.7	9	9
9	749.3	745.1	10	10
19	717.8	712.7	11	11
8	711.1	707.9	12	12
7	613.4	610.1	13	13
20	515.8	511.7	14	14
6	452.9	449.6	15	15
21	396.9	393.0	16	16
22	348.8	345.8	17	17
23	347.3	344.5	18	18
0	226.2	223.0	19	19
5	204.1	202.5	20	20
4	195.5	193.3	21	21
1	173.5	171.2	22	22
2	135.9	133.9	23	24
3	135.8	134.0	24	23
*/

/* ---------- c3. Q3 - average driver income per trip by weekday ---------- */

-- c3a. Average income per trip by weekday, all vs excl, delta and rank
WITH d AS (
    SELECT weekday_num, weekday_name,
           SUM(driver_income) / COUNT(*) AS inc_all,
           SUM(CASE WHEN exclude_reason IS NULL THEN driver_income END)
             / SUM(CASE WHEN exclude_reason IS NULL THEN 1 END) AS inc_excl
    FROM core.trips GROUP BY weekday_num, weekday_name
)
SELECT weekday_num, weekday_name,
       CAST(inc_all  AS decimal(10,2)) AS avg_income_all,
       CAST(inc_excl AS decimal(10,2)) AS avg_income_excl,
       CAST(100.0 * (inc_all - inc_excl) / inc_excl AS decimal(7,2)) AS delta_pct,
       RANK() OVER (ORDER BY inc_all  DESC) AS rank_all,
       RANK() OVER (ORDER BY inc_excl DESC) AS rank_excl
FROM d
ORDER BY rank_all;
-- Result:
/*
weekday_num	weekday_name	avg_income_all	avg_income_excl	delta_pct	rank_all	rank_excl
1	Monday	19.21	16.27	18.11	1	6
7	Sunday	16.93	17.07	-0.81	2	1
5	Friday	16.39	16.49	-0.59	3	2
4	Thursday	16.24	16.33	-0.57	4	3
6	Saturday	16.19	16.28	-0.54	5	5
2	Tuesday	16.19	16.28	-0.58	6	4
3	Wednesday	16.06	16.17	-0.69	7	7
*/


/* ---------- c4. Q4 - tip per mile by vehicle type ---------- */

-- c4a. Tip per mile, card payments only, all vs excl
SELECT vehicle_type,
       COUNT(*) AS card_trips_all,
       CAST(SUM(tip_amount) / NULLIF(SUM(trip_distance), 0) AS decimal(10,3)) AS tip_per_mile_all,
       CAST(SUM(CASE WHEN exclude_reason IS NULL THEN tip_amount END)
            / NULLIF(SUM(CASE WHEN exclude_reason IS NULL THEN trip_distance END), 0) AS decimal(10,3)) AS tip_per_mile_excl,
       CAST(MAX(trip_distance) AS decimal(12,2)) AS max_miles_all
FROM core.trips
WHERE payment_type_id = 1
GROUP BY vehicle_type
ORDER BY tip_per_mile_all DESC;
-- Result:
/*
vehicle_type	card_trips_all	tip_per_mile_all	tip_per_mile_excl	max_miles_all
Unknown	14115	1.002	1.003	138.80
Private	463101	0.943	0.944	305.10
Medium Car	19711	0.924	0.925	48.63
Big Car	5	NULL	NULL	0.00
*/

-- c4b. Same on all payment types (the original Q4 view, before the card-only correction)
SELECT vehicle_type,
       CAST(SUM(tip_amount) / NULLIF(SUM(trip_distance), 0) AS decimal(10,3)) AS tip_per_mile_all,
       CAST(SUM(CASE WHEN exclude_reason IS NULL THEN tip_amount END)
            / NULLIF(SUM(CASE WHEN exclude_reason IS NULL THEN trip_distance END), 0) AS decimal(10,3)) AS tip_per_mile_excl
FROM core.trips
GROUP BY vehicle_type
ORDER BY tip_per_mile_all DESC;
-- Result:
/*
vehicle_type	tip_per_mile_all	tip_per_mile_excl
Medium Car	0.614	0.616
Private	0.600	0.614
Unknown	0.056	0.168
Big Car	NULL	NULL
*/


/* ---------- c5. q5 - boroughs, zones, airports ---------- */

-- c5a. Pickups and average income per trip by pickup borough, all vs excl
SELECT ISNULL(z.borough, 'Not in lookup') AS borough,
       COUNT(*) AS pickups_all,
       SUM(CASE WHEN t.exclude_reason IS NULL THEN 1 ELSE 0 END) AS pickups_excl,
       CAST(100.0 * COUNT(*) / SUM(COUNT(*)) OVER () AS decimal(5,2)) AS pct_all,
       CAST(SUM(t.driver_income) / COUNT(*) AS decimal(10,2)) AS avg_income_all,
       CAST(SUM(CASE WHEN t.exclude_reason IS NULL THEN t.driver_income END)
            / SUM(CASE WHEN t.exclude_reason IS NULL THEN 1 END) AS decimal(10,2)) AS avg_income_excl
FROM core.trips AS t
LEFT JOIN core.zone AS z ON z.location_id = t.pu_location_id
GROUP BY ISNULL(z.borough, 'Not in lookup')
ORDER BY pickups_all DESC;
-- Result:
/*
borough	pickups_all	pickups_excl	pct_all	avg_income_all	avg_income_excl
Manhattan	775335	770010	86.33	14.62	14.17
Queens	54457	53869	6.06	33.44	33.68
Brooklyn	37177	36891	4.14	28.43	28.53
Bronx	21821	21679	2.43	27.35	27.47
Unknown	8419	8178	0.94	20.94	21.39
Staten Island	884	860	0.10	65.29	66.15
EWR	38	36	0.00	69.25	74.86
*/
-- c5b. Airports: pickups, drop-offs and average income per pickup, all vs excl
SELECT z.zone,
       SUM(CASE WHEN t.pu_location_id = z.location_id THEN 1 ELSE 0 END) AS pickups_all,
       SUM(CASE WHEN t.do_location_id = z.location_id THEN 1 ELSE 0 END) AS dropoffs_all,
       CAST(SUM(CASE WHEN t.pu_location_id = z.location_id THEN t.driver_income END)
            / NULLIF(SUM(CASE WHEN t.pu_location_id = z.location_id THEN 1 END), 0) AS decimal(10,2)) AS avg_income_all,
       CAST(SUM(CASE WHEN t.pu_location_id = z.location_id AND t.exclude_reason IS NULL THEN t.driver_income END)
            / NULLIF(SUM(CASE WHEN t.pu_location_id = z.location_id AND t.exclude_reason IS NULL THEN 1 END), 0) AS decimal(10,2)) AS avg_income_excl
FROM core.zone AS z
JOIN core.trips AS t ON z.location_id IN (t.pu_location_id, t.do_location_id)
WHERE z.zone LIKE '%Airport%'
GROUP BY z.zone
ORDER BY pickups_all DESC;
-- Result:
/*
zone	pickups_all	dropoffs_all	avg_income_all	avg_income_excl
JFK Airport	12844	2652	48.15	48.20
LaGuardia Airport	11482	2598	32.98	33.27
Newark Airport	38	534	69.25	74.86
*/


/* ---------- c6. q6 - income per minute and speed by hour ---------- */

-- c6a. Income per minute and average speed by pickup hour, all vs excl, with rank
WITH h AS (
    SELECT pickup_hour,
           SUM(driver_income) / NULLIF(SUM(duration_min), 0) AS ipm_all,
           SUM(CASE WHEN exclude_reason IS NULL THEN driver_income END)
             / NULLIF(SUM(CASE WHEN exclude_reason IS NULL THEN duration_min END), 0) AS ipm_excl,
           SUM(trip_distance) / NULLIF(SUM(duration_min) / 60.0, 0) AS mph_all,
           SUM(CASE WHEN exclude_reason IS NULL THEN trip_distance END)
             / NULLIF(SUM(CASE WHEN exclude_reason IS NULL THEN duration_min END) / 60.0, 0) AS mph_excl,
           MIN(duration_min) AS min_minutes_all
    FROM core.trips GROUP BY pickup_hour
)
SELECT pickup_hour,
       CAST(ipm_all  AS decimal(10,3)) AS income_per_min_all,
       CAST(ipm_excl AS decimal(10,3)) AS income_per_min_excl,
       CAST(100.0 * (ipm_all - ipm_excl) / ipm_excl AS decimal(8,2)) AS delta_pct,
       CAST(mph_all  AS decimal(10,2)) AS mph_all,
       CAST(mph_excl AS decimal(10,2)) AS mph_excl,
       CAST(min_minutes_all AS decimal(12,1)) AS min_minutes_all,
       RANK() OVER (ORDER BY ipm_all  DESC) AS rank_all,
       RANK() OVER (ORDER BY ipm_excl DESC) AS rank_excl
FROM h
ORDER BY pickup_hour;
-- Result: (a negative or huge value in an hour means one extreme trip dominates that hour)

/*
pickup_hour	income_per_min_all	income_per_min_excl	delta_pct	mph_all	mph_excl	min_minutes_all	rank_all	rank_excl
0	1.241	1.448	-14.29	25.48	22.17	0.0	8	7
1	1.348	1.542	-12.58	20.18	23.01	0.0	5	5
2	1.349	1.584	-14.81	20.95	24.45	0.0	4	3
3	1.510	1.660	-9.07	56.07	26.37	0.0	2	2
4	-1.794	1.722	-204.20	-60.98	29.22	-531231.2	24	1
5	1.448	1.554	-6.79	87.64	26.07	0.0	3	4
6	1.195	1.433	-16.61	110.55	20.46	-0.2	12	10
7	1.171	1.351	-13.35	29.57	17.88	-0.2	15	14
8	1.191	1.298	-8.26	42.99	15.88	0.0	13	16
9	1.174	1.289	-8.89	13.52	14.75	0.0	14	17
10	1.108	1.289	-14.05	13.01	15.04	0.0	17	18
11	1.073	1.270	-15.50	16.40	14.71	0.0	19	19
12	1.057	1.266	-16.55	28.63	14.53	0.0	20	20
13	0.998	1.245	-19.86	11.48	14.26	0.0	23	22
14	1.005	1.221	-17.71	20.59	14.19	0.0	22	23
15	1.042	1.203	-13.40	15.45	14.71	-0.2	21	24
16	1.101	1.253	-12.20	14.74	15.12	0.0	18	21
17	1.162	1.322	-12.10	14.68	15.75	0.0	16	15
18	1.212	1.399	-13.30	25.43	16.83	0.0	11	13
19	1.271	1.426	-10.84	16.24	18.06	0.0	7	11
20	2.227	1.438	54.92	16.32	18.88	0.0	1	9
21	1.234	1.444	-14.52	16.82	19.53	0.0	10	8
22	1.285	1.453	-11.59	18.91	21.25	0.0	6	6
23	1.240	1.409	-12.02	35.04	22.74	-0.2	9	12
*/


/* ---------- c7. TLC indicators (Vendor KPI cards) ---------- */

-- c7a. KPI cards, all vs excl, 61 days
SELECT CAST(COUNT(*) / 61.0 AS decimal(10,1))                                                   AS trips_per_day_all,
       CAST(SUM(CASE WHEN exclude_reason IS NULL THEN 1 ELSE 0 END) / 61.0 AS decimal(10,1))    AS trips_per_day_excl,
       CAST(SUM(total_amount - tip_amount) / 61.0 AS decimal(14,2))                             AS farebox_per_day_all,
       CAST(SUM(CASE WHEN exclude_reason IS NULL THEN total_amount - tip_amount END) / 61.0 AS decimal(14,2)) AS farebox_per_day_excl,
       CAST(AVG(duration_min) AS decimal(10,2))                                                 AS avg_minutes_all,
       CAST(AVG(CASE WHEN exclude_reason IS NULL THEN duration_min END) AS decimal(10,2))       AS avg_minutes_excl,
       CAST(100.0 * SUM(CASE WHEN payment_type_id = 1 THEN 1 ELSE 0 END)
            / NULLIF(SUM(CASE WHEN payment_type_id IS NOT NULL THEN 1 ELSE 0 END), 0) AS decimal(5,2)) AS pct_card_known_all,
       CAST(100.0 * SUM(CASE WHEN payment_type_id = 1 AND exclude_reason IS NULL THEN 1 ELSE 0 END)
            / NULLIF(SUM(CASE WHEN payment_type_id IS NOT NULL AND exclude_reason IS NULL THEN 1 ELSE 0 END), 0) AS decimal(5,2)) AS pct_card_known_excl
FROM core.trips;
-- Result:
/*
trips_per_day_all	trips_per_day_excl	farebox_per_day_all	farebox_per_day_excl	avg_minutes_all	avg_minutes_excl	pct_card_known_all	pct_card_known_excl
14723.5	14615.1	257472.94	250330.28	13.46	12.23	63.02	63.40
*/

-- c7b. Driver KPI cards, all vs excl
SELECT CAST(SUM(driver_income) / COUNT(*) AS decimal(10,2)) AS avg_income_all,
       CAST(SUM(CASE WHEN exclude_reason IS NULL THEN driver_income END)
            / SUM(CASE WHEN exclude_reason IS NULL THEN 1 END) AS decimal(10,2)) AS avg_income_excl,
       CAST(SUM(driver_income) / NULLIF(SUM(duration_min), 0) AS decimal(10,3)) AS income_per_min_all,
       CAST(SUM(CASE WHEN exclude_reason IS NULL THEN driver_income END)
            / NULLIF(SUM(CASE WHEN exclude_reason IS NULL THEN duration_min END), 0) AS decimal(10,3)) AS income_per_min_excl,
       CAST(SUM(trip_distance) / NULLIF(SUM(duration_min) / 60.0, 0) AS decimal(10,2)) AS mph_all,
       CAST(SUM(CASE WHEN exclude_reason IS NULL THEN trip_distance END)
            / NULLIF(SUM(CASE WHEN exclude_reason IS NULL THEN duration_min END) / 60.0, 0) AS decimal(10,2)) AS mph_excl
FROM core.trips;
-- Result:
/*
avg_income_all	avg_income_excl	income_per_min_all	income_per_min_excl	mph_all	mph_excl
16.76	16.38	1.245	1.339	25.60	17.13
*/


/* ---------- c8. Where the extremes sit (explains the changes above) ---------- */

-- c8a. The 10 most extreme flagged trips by size of the value
SELECT TOP 10 exclude_reason, pickup_date, weekday_name, pickup_hour, vehicle_type,
       pu_location_id, payment_type_id,
       CAST(total_amount  AS decimal(14,2)) AS total_amount,
       CAST(driver_income AS decimal(14,2)) AS driver_income,
       CAST(trip_distance AS decimal(14,2)) AS trip_distance,
       CAST(duration_min  AS decimal(14,1)) AS duration_min
FROM core.trips
WHERE exclude_reason IS NOT NULL
ORDER BY (ABS(ISNULL(total_amount, 0)) / 1000.0 + ABS(ISNULL(trip_distance, 0)) / 200.0
        + ABS(ISNULL(duration_min, 0)) / 300.0) DESC;
-- Result:
/*
exclude_reason	pickup_date	weekday_name	pickup_hour	vehicle_type	pu_location_id	payment_type_id	total_amount	driver_income	trip_distance	duration_min
duration_le_0	2020-06-14	Sunday	4	Private	262	1	43.10	36.18	8.10	-531231.2
distance_gt_200	2020-05-02	Saturday	6	Unknown	89	NULL	35.64	32.34	297004.51	27.0
distance_gt_200	2020-06-24	Wednesday	12	Unknown	236	NULL	27.37	26.57	220386.23	18.0
distance_gt_200	2020-05-11	Monday	8	Unknown	191	NULL	54.38	53.58	148342.26	32.0
distance_gt_200	2020-05-17	Sunday	4	Unknown	254	NULL	30.71	29.91	130587.13	121.0
distance_gt_200	2020-05-09	Saturday	5	Unknown	254	NULL	28.83	28.03	128870.92	20.0
distance_gt_200	2020-05-05	Tuesday	18	Unknown	241	NULL	13.98	13.18	127377.15	27.0
distance_gt_200	2020-05-28	Thursday	6	Unknown	65	NULL	17.55	16.75	120206.70	78.0
distance_gt_200	2020-06-01	Monday	3	Unknown	76	NULL	27.63	26.83	97878.35	18.0
distance_gt_200	2020-05-16	Saturday	8	Unknown	250	NULL	11.55	10.75	95650.01	17.0
*/

-- Conclusions: 
-- c0. All 898,131 trips are kept. 6,608 (0.74%) carry a data quality flag: negative fare 4,062,
--     duration over 300 min 1,281, duration of 0 or less 1,211, distance over 200 mi 30,
--     pickup date outside May-June 23, fare over $1,000 1.
-- c1. Q1 does not change. On every weekday Private cars are 80.8-82.7% of trips, Unknown 14.0-15.7%,
--     Medium Car 3.1-3.6%; Big Car appears 5 times. Friday (17,099.7 trips per day) and Tuesday
--     (16,761.6) are the busiest, Sunday (9,673.0) the quietest, with the same ranking in both views.
-- c2. Q2 does not change. The top 5 hours are 13:00-17:00 in both views; 15:00 peaks with 1,085.2
--     trips per day (1,076.8 without flagged trips). Only hours 2 and 3 swap places at the bottom.
-- c3. Q3 changes. With all trips Monday has the highest average income per trip ($19.21, +18.1% vs
--     $16.27), followed by Sunday ($16.93). Without flagged trips Sunday ($17.07) and Friday ($16.49)
--     lead and Monday is sixth. The other weekdays change by less than 1%, so the Monday jump comes
--     from a few flagged trips (see 10, d1).
-- c4. Q4 does not change on card payments: Unknown $1.002, Private $0.943, Medium Car $0.924 per mile,
--     all within 0.2% of the values without flagged trips. On all payment types Unknown falls to
--     $0.056 because the largest distance errors (up to 297,004.51 mi, c8a) are Unknown trips without
--     payment data, which supports using card payments only.
-- c5. q5 does not change. Manhattan has 86.33% of pickups (775,335), then Queens 6.06%, Brooklyn 4.14%,
--     Bronx 2.43%. Income per trip keeps the same order; Manhattan rises from $14.17 to $14.62 (+3.2%).
--     JFK: 12,844 pickups at $48.15; LaGuardia: 11,482 at $32.98; Newark: 38, too few to conclude.
-- c6. q6 changes for two hours. 04:00 becomes negative (-$1.794 per minute, -60.98 mph) because one
--     trip has a duration of -531,231.2 min (c8a); 20:00 becomes the best hour ($2.227, +54.9%), driven
--     by flagged trips (see 10, d1). In the other 22 hours income per minute is 6.8-19.9% lower, because
--     trips over 300 min add minutes, but the pattern holds: the afternoon pays least (13:00 $0.998,
--     14:00 $1.005) and the early night more (03:00 $1.510, 05:00 $1.448). All-trip speeds are not
--     physically meaningful (up to 110.55 mph at 06:00) because of distance errors.
-- c7. Trips per day (14,723.5) now match the official TLC figures (11,237 and 18,326 per day, about
--     898,127 trips in 61 days). Farebox per day $257,472.94 (+2.9%), average minutes 13.46 (+10.1%),
--     card share of known payments 63.02%. Driver cards: income per trip $16.76 (+2.3%), income per
--     minute $1.245 (-7.0%), speed 25.60 mph (+49.4%, distorted by distance errors).
-- c8. The most extreme flagged trips: one duration of -531,231.2 min (Sunday, 04:00) and nine distances
--     of 95,650.01-297,004.51 mi, all Unknown vehicles without payment data.
