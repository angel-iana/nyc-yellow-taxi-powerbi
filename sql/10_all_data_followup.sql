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

-- d1b. Q3 check: Monday average income per trip without the single highest-income trip
SELECT CAST(SUM(driver_income) / COUNT(*) AS decimal(10,2)) AS monday_avg_without_top1
FROM core.trips
WHERE weekday_num = 1
  AND driver_income < (SELECT MAX(driver_income) FROM core.trips WHERE weekday_num = 1);
-- Result:

-- d2. Q2: share of the 13:00-17:00 window, all vs excl
SELECT CAST(100.0 * SUM(CASE WHEN pickup_hour BETWEEN 13 AND 17 THEN 1 ELSE 0 END) / COUNT(*) AS decimal(5,2)) AS pct_13_to_17_all,
       CAST(100.0 * SUM(CASE WHEN pickup_hour BETWEEN 13 AND 17 AND exclude_reason IS NULL THEN 1 ELSE 0 END)
            / SUM(CASE WHEN exclude_reason IS NULL THEN 1 ELSE 0 END) AS decimal(5,2)) AS pct_13_to_17_excl
FROM core.trips;
-- Result: (excl expected 35.44)

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

-- d5. q6: income per minute of the 13:00-17:00 window vs the other hours, all vs excl
SELECT CASE WHEN pickup_hour BETWEEN 13 AND 17 THEN '13:00-17:00' ELSE 'other hours' END AS time_window,
       CAST(SUM(driver_income) / NULLIF(SUM(duration_min), 0) AS decimal(10,3)) AS income_per_min_all,
       CAST(SUM(CASE WHEN exclude_reason IS NULL THEN driver_income END)
            / NULLIF(SUM(CASE WHEN exclude_reason IS NULL THEN duration_min END), 0) AS decimal(10,3)) AS income_per_min_excl
FROM core.trips
GROUP BY CASE WHEN pickup_hour BETWEEN 13 AND 17 THEN '13:00-17:00' ELSE 'other hours' END;
-- Result: (excl expected 1.248 / 1.390)

-- d6. JFK flat fare (RatecodeID 2), all vs excl
SELECT COUNT(*) AS trips_all,
       SUM(CASE WHEN exclude_reason IS NULL THEN 1 ELSE 0 END) AS trips_excl,
       CAST(SUM(driver_income) / COUNT(*) AS decimal(10,2)) AS avg_income_all,
       CAST(AVG(duration_min) AS decimal(10,2)) AS avg_minutes_all
FROM core.trips
WHERE ratecode_id = 2;
-- Result: (excl expected 6,693 trips, $61.29, 27.81 min)

-- Conclusions: written after the results.
