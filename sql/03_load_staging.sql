/* 03 - Load the CSV files into staging with BULK INSERT*/
USE NYCTaxi;
GO

TRUNCATE TABLE stg.yellow_tripdata;   -- safe to re-run: start empty
TRUNCATE TABLE stg.taxi_zone_lookup;

BULK INSERT stg.yellow_tripdata
FROM 'C:\NYCTaxiData\yellow_tripdata_2020-05.csv'
WITH (FORMAT = 'CSV', FIRSTROW = 2, FIELDTERMINATOR = ',', ROWTERMINATOR = '\n', TABLOCK);
-- expected: (348371 rows affected)

BULK INSERT stg.yellow_tripdata
FROM 'C:\NYCTaxiData\yellow_tripdata_2020-06.csv'
WITH (FORMAT = 'CSV', FIRSTROW = 2, FIELDTERMINATOR = ',', ROWTERMINATOR = '\n', TABLOCK);
-- expected: (549760 rows affected)

BULK INSERT stg.taxi_zone_lookup
FROM 'C:\NYCTaxiData\taxi+_zone_lookup.csv'
WITH (FORMAT = 'CSV', FIRSTROW = 2, FIELDTERMINATOR = ',', ROWTERMINATOR = '\n', FIELDQUOTE = '"');
-- expected: (265 rows affected)
GO

-- check: 898131 trips, 265 zones
SELECT 'trips' AS tbl, COUNT(*) AS rows_loaded FROM stg.yellow_tripdata
UNION ALL
SELECT 'zones', COUNT(*) FROM stg.taxi_zone_lookup;

-- check per month (pickup month, as text)
SELECT LEFT(tpep_pickup_datetime, 7) AS pickup_month, COUNT(*) AS trips
FROM stg.yellow_tripdata
GROUP BY LEFT(tpep_pickup_datetime, 7)
ORDER BY pickup_month;

-- check the last column has no hidden CR character (should return 0)
SELECT COUNT(*) AS rows_with_cr
FROM stg.yellow_tripdata
WHERE congestion_surcharge LIKE '%' + CHAR(13) + '%';
