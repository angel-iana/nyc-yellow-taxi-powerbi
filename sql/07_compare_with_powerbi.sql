/* 07 - Compare SQL with Power BI
   Same data, two tools: if a number differs, one of the two has a mistake.
   Part A has fixed expected values (from the CSV files).
   Part B: run the query, then build the same table in Power BI and compare.
   Fill in the Result / Conclusion lines.
*/
USE NYCTaxi;
GO

/* ---------- Part A: structure checks ---------- */

-- A1. Rows before any filter (expected 898131 = Power BI before exclusions)
SELECT COUNT(*) AS trips FROM core.trips;
-- Result:
-- Conclusion:

-- A2. Trips per vendor, empty VendorID shown as 3 like in Power Query
--     (expected 1 = 326613, 2 = 461910, 3 = 109608)
SELECT ISNULL(vendor_id, 3) AS vendor_id, COUNT(*) AS trips
FROM core.trips
GROUP BY ISNULL(vendor_id, 3)
ORDER BY vendor_id;
-- Result:
-- Conclusion:

-- A3. Vehicle type, all rows (expected Private 734499, Unknown 132520,
--     Medium Car 31107, Big Car 5)
SELECT vehicle_type, COUNT(*) AS trips
FROM core.trips
GROUP BY vehicle_type
ORDER BY trips DESC;
-- Result:
-- Conclusion:

-- A4. Rows kept after the exclusion rules (expected 891523)
SELECT COUNT(*) AS kept_trips
FROM core.trips
WHERE exclude_reason IS NULL;
-- Result:
-- Conclusion:

/* ---------- Part B: business questions (compare with your Power BI visuals) ---------- */

-- B1. Q1 - vehicle types by weekday (matrix: weekday x vehicle_type)
SELECT weekday_num, weekday_name, vehicle_type, COUNT(*) AS trips
FROM core.trips
WHERE exclude_reason IS NULL
GROUP BY weekday_num, weekday_name, vehicle_type
ORDER BY weekday_num, trips DESC;
-- Result:
-- Conclusion:

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
-- Conclusion:

-- B3. Q3 - average driver income per trip by weekday (fare + extra + tip)
SELECT weekday_num, weekday_name,
       CAST(SUM(driver_income) / COUNT(*) AS decimal(10,2)) AS avg_income_per_trip
FROM core.trips
WHERE exclude_reason IS NULL
GROUP BY weekday_num, weekday_name
ORDER BY avg_income_per_trip DESC;
-- Result:
-- Conclusion:

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
-- Conclusion:
