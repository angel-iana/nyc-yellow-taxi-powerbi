/* 05 - core.trips: typed, with derived columns and an exclude_reason flag
   NULLIF(x,'') turns empty text into NULL; TRY_CONVERT returns NULL instead of an error.
   No row is deleted here: rows we don't want get an exclude_reason, so every decision stays visible.
*/
USE NYCTaxi;
GO

DROP TABLE IF EXISTS core.trips;

SELECT
    IDENTITY(int, 1, 1) AS trip_id,
    t.vendor_id, t.pickup_datetime, t.dropoff_datetime, t.passenger_count, t.trip_distance,
    t.ratecode_id, t.store_and_fwd_flag, t.pu_location_id, t.do_location_id, t.payment_type_id,
    t.fare_amount, t.extra, t.mta_tax, t.tip_amount, t.tolls_amount,
    t.improvement_surcharge, t.total_amount, t.congestion_surcharge,

    -- derived columns
    CAST(t.pickup_datetime AS date)                         AS pickup_date,
    DATEPART(hour, t.pickup_datetime)                       AS pickup_hour,      -- 10:56 -> 10
    d.weekday_num,                                                               -- Monday = 1
    CHOOSE(d.weekday_num, 'Monday','Tuesday','Wednesday','Thursday',
                          'Friday','Saturday','Sunday')     AS weekday_name,
    d.duration_min,
    CASE WHEN t.passenger_count BETWEEN 1 AND 4 THEN 'Private'
         WHEN t.passenger_count BETWEEN 5 AND 6 THEN 'Medium Car'
         WHEN t.passenger_count >= 7            THEN 'Big Car'
         ELSE 'Unknown' END                                 AS vehicle_type,
    t.fare_amount + t.extra + t.tip_amount                  AS driver_income,

    -- first rule that matches wins; NULL = row is used in analysis
    CASE WHEN t.pickup_datetime <  '2020-05-01'
           OR t.pickup_datetime >= '2020-07-01' THEN 'out_of_period'
         WHEN d.duration_min <= 0               THEN 'duration_le_0'
         WHEN d.duration_min > 300              THEN 'duration_gt_300'
         WHEN t.fare_amount < 0                 THEN 'negative_fare'
         WHEN t.trip_distance > 200             THEN 'distance_gt_200'
         WHEN t.fare_amount > 1000              THEN 'fare_gt_1000'
    END                                                     AS exclude_reason
INTO core.trips
FROM stg.yellow_tripdata AS s
CROSS APPLY (SELECT
    TRY_CONVERT(tinyint,       NULLIF(s.VendorID, ''))              AS vendor_id,
    TRY_CONVERT(datetime2(0),  s.tpep_pickup_datetime, 120)         AS pickup_datetime,
    TRY_CONVERT(datetime2(0),  s.tpep_dropoff_datetime, 120)        AS dropoff_datetime,
    TRY_CONVERT(tinyint,       NULLIF(s.passenger_count, ''))       AS passenger_count,
    TRY_CONVERT(decimal(10,2), NULLIF(s.trip_distance, ''))         AS trip_distance,
    TRY_CONVERT(tinyint,       NULLIF(s.RatecodeID, ''))            AS ratecode_id,
    CAST(NULLIF(s.store_and_fwd_flag, '') AS char(1))               AS store_and_fwd_flag,
    TRY_CONVERT(smallint,      NULLIF(s.PULocationID, ''))          AS pu_location_id,
    TRY_CONVERT(smallint,      NULLIF(s.DOLocationID, ''))          AS do_location_id,
    TRY_CONVERT(tinyint,       NULLIF(s.payment_type, ''))          AS payment_type_id,
    TRY_CONVERT(decimal(10,2), NULLIF(s.fare_amount, ''))           AS fare_amount,
    TRY_CONVERT(decimal(10,2), NULLIF(s.extra, ''))                 AS extra,
    TRY_CONVERT(decimal(10,2), NULLIF(s.mta_tax, ''))               AS mta_tax,
    TRY_CONVERT(decimal(10,2), NULLIF(s.tip_amount, ''))            AS tip_amount,
    TRY_CONVERT(decimal(10,2), NULLIF(s.tolls_amount, ''))          AS tolls_amount,
    TRY_CONVERT(decimal(10,2), NULLIF(s.improvement_surcharge, '')) AS improvement_surcharge,
    TRY_CONVERT(decimal(10,2), NULLIF(s.total_amount, ''))          AS total_amount,
    TRY_CONVERT(decimal(10,2), NULLIF(s.congestion_surcharge, ''))  AS congestion_surcharge
) AS t
CROSS APPLY (SELECT
    CAST(DATEDIFF(second, t.pickup_datetime, t.dropoff_datetime) / 60.0 AS decimal(10,2)) AS duration_min,
    DATEDIFF(day, '19000101', CAST(t.pickup_datetime AS date)) % 7 + 1                  AS weekday_num  -- 1900-01-01 was a Monday
) AS d;
GO

ALTER TABLE core.trips ADD CONSTRAINT PK_core_trips PRIMARY KEY (trip_id);
GO

-- check 1: same row count as staging (898131)
SELECT COUNT(*) AS core_rows FROM core.trips;

-- check 2: nothing failed to convert (a value present in staging but NULL in core) -> all 0
SELECT
    SUM(CASE WHEN pickup_datetime IS NULL THEN 1 ELSE 0 END) AS bad_pickup,
    SUM(CASE WHEN fare_amount     IS NULL THEN 1 ELSE 0 END) AS bad_fare,
    SUM(CASE WHEN trip_distance   IS NULL THEN 1 ELSE 0 END) AS bad_distance
FROM core.trips;

-- check 3: how many rows each rule flags
SELECT ISNULL(exclude_reason, 'kept') AS reason, COUNT(*) AS trips
FROM core.trips
GROUP BY exclude_reason
ORDER BY trips DESC;
