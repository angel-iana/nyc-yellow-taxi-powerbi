/* 10 - Follow-up checks for view A (all data) after 09
   d1 finds the trips behind the Q3 (Monday) and q6 (20:00) jumps.
   d2-d5 recompute the numbers that view A needs and 09 did not cover.
*/
USE NYCTaxi;
GO

-- d1a. The 5 trips with the highest driver income (expected: the source of the Monday and 20:00 jumps)
SELECT TOP 5 t.exclude_reason, t.pickup_date, t.weekday_name, t.pickup_hour, t.vehicle_type,
       z.borough, z.zone, t.payment_type_id,
       CAST(t.total_amount  AS decimal(14,2)) AS total_amount,
       CAST(t.driver_income AS decimal(14,2)) AS driver_income,
       CAST(t.trip_distance AS decimal(14,2)) AS trip_distance,
       CAST(t.duration_min  AS decimal(14,1)) AS duration_min
FROM core.trips AS t
LEFT JOIN core.zone AS z ON z.location_id = t.pu_location_id
ORDER BY t.driver_income DESC;
-- Result:
/*
exclude_reason	pickup_date	weekday_name	pickup_hour	vehicle_type	borough	zone	payment_type_id	total_amount	driver_income	trip_distance	duration_min
fare_gt_1000	2020-05-04	Monday	20	Private	Manhattan	Lincoln Square East	3	429562.25	429562.25	0.00	0.9
duration_gt_300	2020-06-25	Thursday	8	Private	Manhattan	West Chelsea/Hudson Yards	1	1141.10	1134.18	191.80	355.8
duration_gt_300	2020-05-16	Saturday	12	Private	Manhattan	Alphabet City	1	1042.82	977.80	305.10	395.3
NULL	2020-05-05	Tuesday	20	Unknown	Unknown	NA	3	950.30	950.00	0.30	0.7
duration_gt_300	2020-06-25	Thursday	10	Private	Manhattan	Penn Station/Madison Sq West	1	944.05	908.01	240.70	330.9
*/

-- d1b. Q3 check: Monday average income per trip without the single highest-income trip
SELECT CAST(SUM(driver_income) / COUNT(*) AS decimal(10,2)) AS monday_avg_without_top1
FROM core.trips
WHERE weekday_num = 1
  AND driver_income < (SELECT MAX(driver_income) FROM core.trips WHERE weekday_num = 1);
-- Result:   monday_avg_without_top1 16.15

-- d2. Q2: share of the 13:00-17:00 window, all vs excl
SELECT CAST(100.0 * SUM(CASE WHEN pickup_hour BETWEEN 13 AND 17 THEN 1 ELSE 0 END) / COUNT(*) AS decimal(5,2)) AS pct_13_to_17_all,
       CAST(100.0 * SUM(CASE WHEN pickup_hour BETWEEN 13 AND 17 AND exclude_reason IS NULL THEN 1 ELSE 0 END)
            / SUM(CASE WHEN exclude_reason IS NULL THEN 1 ELSE 0 END) AS decimal(5,2)) AS pct_13_to_17_excl
FROM core.trips;
-- Result:
/*
pct_13_to_17_all	pct_13_to_17_excl
35.44	35.44
*/
-- d3. q5: top 10 pickup zones, all data, with share and running share
WITH zones AS (
    SELECT z.borough, z.zone, COUNT(*) AS trips
    FROM core.trips AS t
    JOIN core.zone AS z ON z.location_id = t.pu_location_id
    GROUP BY z.borough, z.zone
)
SELECT TOP 10 RANK() OVER (ORDER BY trips DESC) AS rnk, borough, zone, trips,
       CAST(100.0 * trips / SUM(trips) OVER () AS decimal(5,2)) AS pct_of_trips,
       CAST(100.0 * SUM(trips) OVER (ORDER BY trips DESC ROWS UNBOUNDED PRECEDING) / SUM(trips) OVER () AS decimal(5,2)) AS running_pct
FROM zones
ORDER BY trips DESC;
-- Result:
/*
rnk	borough	zone	trips	pct_of_trips	running_pct
1	Manhattan	Kips Bay	35327	3.93	3.93
2	Manhattan	Upper East Side North	35128	3.91	7.84
3	Manhattan	Upper East Side South	32697	3.64	11.49
4	Manhattan	Lenox Hill East	31940	3.56	15.04
5	Manhattan	Yorkville West	31194	3.47	18.51
6	Manhattan	Lenox Hill West	30654	3.41	21.93
7	Manhattan	Upper West Side North	30336	3.38	25.31
8	Manhattan	Penn Station/Madison Sq West	30152	3.36	28.66
9	Manhattan	East Harlem South	29087	3.24	31.90
10	Manhattan	Clinton East	28843	3.21	35.11
*/

-- d4. q5: airport share of pickups and drop-offs, all data
SELECT 'pickup' AS direction,
       SUM(CASE WHEN z.zone LIKE '%Airport%' THEN 1 ELSE 0 END) AS airport_trips,
       CAST(100.0 * SUM(CASE WHEN z.zone LIKE '%Airport%' THEN 1 ELSE 0 END) / COUNT(*) AS decimal(5,2)) AS pct_airport
FROM core.trips AS t LEFT JOIN core.zone AS z ON z.location_id = t.pu_location_id
UNION ALL
SELECT 'dropoff',
       SUM(CASE WHEN z.zone LIKE '%Airport%' THEN 1 ELSE 0 END),
       CAST(100.0 * SUM(CASE WHEN z.zone LIKE '%Airport%' THEN 1 ELSE 0 END) / COUNT(*) AS decimal(5,2))
FROM core.trips AS t LEFT JOIN core.zone AS z ON z.location_id = t.do_location_id;
-- Result:
/*
direction	airport_trips	pct_airport
pickup	24364	2.71
dropoff	5784	0.64
*/

-- d5. q6: income per minute of the 13:00-17:00 window vs the other hours, all vs excl
SELECT CASE WHEN pickup_hour BETWEEN 13 AND 17 THEN '13:00-17:00' ELSE 'other hours' END AS time_window,
       CAST(SUM(driver_income) / NULLIF(SUM(duration_min), 0) AS decimal(10,3)) AS income_per_min_all,
       CAST(SUM(CASE WHEN exclude_reason IS NULL THEN driver_income END)
            / NULLIF(SUM(CASE WHEN exclude_reason IS NULL THEN duration_min END), 0) AS decimal(10,3)) AS income_per_min_excl
FROM core.trips
GROUP BY CASE WHEN pickup_hour BETWEEN 13 AND 17 THEN '13:00-17:00' ELSE 'other hours' END;
-- Result:
/*
time_window	income_per_min_all	income_per_min_excl
13:00-17:00	1.061	1.248
other hours	1.358	1.390
*/

-- d6. JFK flat fare (RatecodeID 2), all vs excl
SELECT COUNT(*) AS trips_all,
       SUM(CASE WHEN exclude_reason IS NULL THEN 1 ELSE 0 END) AS trips_excl,
       CAST(SUM(driver_income) / COUNT(*) AS decimal(10,2)) AS avg_income_all,
       CAST(AVG(duration_min) AS decimal(10,2)) AS avg_minutes_all
FROM core.trips
WHERE ratecode_id = 2;
-- Result: 
/*
trips_all	trips_excl	avg_income_all	avg_minutes_all
6880	6693	58.85	29.88
*/

-- d7. Out-of-period trips by weekday (explains the Sunday gap vs Power BI)
SELECT weekday_name, COUNT(*) AS trips
FROM core.trips
WHERE pickup_date < '2020-05-01' OR pickup_date > '2020-06-30'
GROUP BY weekday_name
ORDER BY trips DESC;
-- Result:
/*
weekday_name	trips
Thursday	10
Sunday	7
Wednesday	3
Saturday	3
*/

-- Conclusions: 
-- d1. One trip drives both the Q3 and the q6 changes: Monday 2020-05-04, 20:00, Lincoln Square East
--     (Manhattan), $429,562.25, 0 miles, 0.9 min, payment type 3 (no charge). Without it, Monday's
--     average income per trip is $16.15 (d1b), and Sunday and Friday lead again. The fourth trip in the
--     list ($950.00, 0.3 mi, 0.7 min) passes every exclusion rule but is just as implausible: the rules
--     catch impossible values, not every suspicious one.
-- d2. Q2: 13:00-17:00 holds 35.44% of trips in both views.
-- d3. q5: with all trips, the top 10 pickup zones are the same and hold 35.11% of trips; Kips Bay leads
--     with 35,327.
-- d4. q5: airports have 24,364 pickups (2.71%) and 5,784 drop-offs (0.64%).
-- d5. q6: the 13:00-17:00 window pays $1.061 per minute, compared with $1.358 for the other hours
--     ($1.248 vs $1.390 without flagged trips). The afternoon still pays least; the gap is larger with
--     all trips.
-- d6. JFK flat fare: 6,880 trips at $58.85 per trip and 29.88 minutes (6,693 / $61.29 / 27.81 without
--     flagged trips).
-- d7. The 23 out-of-period trips have no weekday in the 61-day calendar, so Power BI leaves them out
--     of the weekday rows but keeps them in the total. Sunday is 9,672.2 in the report (9,673.0 when
--     they are counted by their own date: 7 of the 23 fall on a Sunday).
