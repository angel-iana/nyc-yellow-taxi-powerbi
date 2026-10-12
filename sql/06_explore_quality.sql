/* 06 - Explore the data and check quality */
USE NYCTaxi;
GO

-- 1. Volume per pickup month 
--    group by year + month number (no FORMAT before aggregating)

SELECT YEAR(pickup_datetime) AS pickup_year, MONTH(pickup_datetime) AS pickup_month, COUNT(*) AS trips
FROM core.trips
GROUP BY YEAR(pickup_datetime), MONTH(pickup_datetime)
ORDER BY pickup_year, pickup_month;

-- Result:
/*pickup_year	pickup_month	trips
2008	12	1
2009	1	6
2020	4	4
2020	5	348352
2020	6	549756
2020	7	4
2020	8	1
2020	9	3
2020	10	1
2020	11	3     */

-- Conclusion: 23 trips have pickup dates outside May–June 2020 (2008–2009, Apr, Jul–Nov) – excluded as out_of_period.



-- 2. Rows with empty trip metadata 
SELECT COUNT(*) AS rows_no_metadata,
       CAST(100.0 * COUNT(*) / (SELECT COUNT(*) FROM core.trips) AS decimal(5,1)) AS pct
FROM core.trips
WHERE vendor_id IS NULL;
-- Result:    

/*rows_no_metadata	pct
109608	12.2*/

-- Conclusion:  12.2% of trips have no vendor, passenger, ratecode or payment data – kept in analysis, shown as Unknown / No Vendor.

-- 3. Min / max of the main measures (look for impossible values)
SELECT MIN(trip_distance) AS min_dist, MAX(trip_distance) AS max_dist,
       MIN(fare_amount)   AS min_fare, MAX(fare_amount)   AS max_fare,
       MIN(duration_min)  AS min_dur,  MAX(duration_min)  AS max_dur
FROM core.trips;
-- Result:
/*min_dist	max_dist	min_fare	max_fare	min_dur	max_dur
0.00	297004.51	-240.00	429496.72	-531231.23	4497.57*/
-- Conclusion:  Impossible extremes (297,004 mi, $429,496 fare, −531,231 min) confirm the need for exclusion rules.

-- 4. Problem counts 
SELECT
    SUM(CASE WHEN fare_amount < 0     THEN 1 ELSE 0 END) AS negative_fare,
    SUM(CASE WHEN trip_distance = 0   THEN 1 ELSE 0 END) AS zero_distance,
    SUM(CASE WHEN duration_min <= 0   THEN 1 ELSE 0 END) AS duration_le_0,
    SUM(CASE WHEN duration_min > 300  THEN 1 ELSE 0 END) AS duration_gt_300,
    SUM(CASE WHEN passenger_count = 0 THEN 1 ELSE 0 END) AS zero_passengers,
    SUM(CASE WHEN ratecode_id = 99    THEN 1 ELSE 0 END) AS ratecode_99
FROM core.trips;
-- Result:

/*negative_fare	zero_distance	duration_le_0	duration_gt_300	zero_passengers	ratecode_99
4073	27662	1211	1284	22912	82*/

        -- 4b. Same problems as a percentage of all trips
        WITH counts AS (
            SELECT
                COUNT(*) AS total_trips,
                SUM(CASE WHEN fare_amount < 0     THEN 1 ELSE 0 END) AS negative_fare,
                SUM(CASE WHEN trip_distance = 0   THEN 1 ELSE 0 END) AS zero_distance,
                SUM(CASE WHEN duration_min <= 0   THEN 1 ELSE 0 END) AS duration_le_0,
                SUM(CASE WHEN duration_min > 300  THEN 1 ELSE 0 END) AS duration_gt_300,
                SUM(CASE WHEN passenger_count = 0 THEN 1 ELSE 0 END) AS zero_passengers,
                SUM(CASE WHEN ratecode_id = 99    THEN 1 ELSE 0 END) AS ratecode_99
            FROM core.trips
        )
        SELECT p.problem,
               p.trips,
               CAST(100.0 * p.trips / c.total_trips AS decimal(5,2)) AS pct
        FROM counts AS c
        CROSS APPLY (VALUES
            ('negative_fare',   c.negative_fare),
            ('zero_distance',   c.zero_distance),
            ('duration_le_0',   c.duration_le_0),
            ('duration_gt_300', c.duration_gt_300),
            ('zero_passengers', c.zero_passengers),
            ('ratecode_99',     c.ratecode_99)
        ) AS p(problem, trips)
        ORDER BY p.trips DESC;
        -- Result:
        /*problem	trips	pct
        zero_distance	27662	3.08
        zero_passengers	22912	2.55
        negative_fare	4073	0.45
        duration_gt_300	1284	0.14
        duration_le_0	1211	0.13
        ratecode_99	82	0.01*/


-- Conclusion:    All problems are below 0.5% except 0 miles (3.1%) and 0 passengers (2.6%). 

-- 5. Vehicle type (Big Car has only 5 trips -> Q4 can't say much about it)
SELECT vehicle_type, COUNT(*) AS trips
FROM core.trips
GROUP BY vehicle_type
ORDER BY trips DESC;
-- Result:
/*vehicle_type	trips
Private	734499
Unknown	132520
Medium Car	31107
Big Car	5 */
-- Conclusion:   Big Car has only 5 trips – Q4 cannot draw a conclusion for it; Unknown (132,520) is large because of the empty rows.

-- 6. Payment type with names (join to the lookup)
SELECT ISNULL(p.payment_type_name, '(empty)') AS payment_type, COUNT(*) AS trips
FROM core.trips AS t
LEFT JOIN core.payment_type AS p ON p.payment_type_id = t.payment_type_id
GROUP BY p.payment_type_name
ORDER BY trips DESC;
-- Result:
/*payment_type	trips
Credit card	496932
Cash	278390
(empty)	109608
No charge	9182
Dispute	4007
Unknown	12*/
        -- 6b. Payment type as a percentage of all trips
        SELECT ISNULL(p.payment_type_name, '(empty)') AS payment_type,
                COUNT(*) AS trips,
                CAST(100.0 * COUNT(*) / SUM(COUNT(*)) OVER () AS decimal(5,2)) AS pct
        FROM core.trips AS t
        LEFT JOIN core.payment_type AS p ON p.payment_type_id = t.payment_type_id
        GROUP BY p.payment_type_name
        ORDER BY trips DESC;
        -- Result: 
        /*payment_type	trips	pct
        Credit card	496932	55.33
        Cash	278390	31.00
        (empty)	109608	12.20
        No charge	9182	1.02
        Dispute	4007	0.45
        Unknown	12	0.00*/
       
-- Conclusion:   Card 55%, cash 31%; 109,608 (12%) trips have no payment type.

-- 7. Tips appear only on card payments: average tip by payment type
SELECT t.payment_type_id, AVG(t.tip_amount) AS avg_tip, COUNT(*) AS trips
FROM core.trips AS t
WHERE t.exclude_reason IS NULL
GROUP BY t.payment_type_id
ORDER BY t.payment_type_id;
-- Result:
/*payment_type_id	avg_tip	trips
NULL	1.193724	109090
1	2.685711	496100
2	0.000105	276363
3	0.001350	7861
4	0.009971	2097
5	0.000000	12*/
-- Conclusion:   Tips are recorded almost only on card payments ($2.69 avg vs $0.00 cash) – tip analysis reflects card trips only.

-- 8. Pickups per borough 
SELECT z.borough, COUNT(*) AS pickups
FROM core.trips AS t
JOIN core.zone  AS z ON z.location_id = t.pu_location_id
WHERE t.exclude_reason IS NULL
GROUP BY z.borough
ORDER BY pickups DESC;
-- Result:
/*borough	pickups
Manhattan	770010
Queens	53869
Brooklyn	36891
Bronx	21679
Unknown	8178
Staten Island	860
EWR	36*/

        -- 8b. Pickups per borough as a percentage of kept trips
        SELECT z.borough,
               COUNT(*) AS pickups,
               CAST(100.0 * COUNT(*) / SUM(COUNT(*)) OVER () AS decimal(5,2)) AS pct
        FROM core.trips AS t
        JOIN core.zone  AS z ON z.location_id = t.pu_location_id
        WHERE t.exclude_reason IS NULL
        GROUP BY z.borough
        ORDER BY pickups DESC;
        -- Result:
        /*borough	pickups	pct
        Manhattan	770010	86.37
        Queens	53869	6.04
        Brooklyn	36891	4.14
        Bronx	21679	2.43
        Unknown	8178	0.92
        Staten Island	860	0.10
        EWR	36	0.00*/


-- Conclusion:    Manhattan has 86% of pickups (770,010 of 891,523) – borough charts will be dominated by it; zone level is more useful.

-- 9. First look at a business question: trips per hour of day
SELECT pickup_hour, COUNT(*) AS trips
FROM core.trips
WHERE exclude_reason IS NULL
GROUP BY pickup_hour
ORDER BY pickup_hour;
-- Result:
/*pickup_hour	trips
0	13606
1	10443
2	8167
3	8171
4	11794
5	12351
6	27425
7	37215
8	43180
9	45453
10	49941
11	54195
12	59088
13	61974
14	63787
15	65686
16	62879
17	61587
18	53808
19	43474
20	31215
21	23974
22	21096
23	21014*/

-- Conclusion:      Peak at 15:00 (65,686), lowest at 02:00–03:00 (~8,200); demand builds from 06:00 and stays high until 18:00.
