/* 02 - Staging tables: one column per CSV column, all text.
   Text accepts everything (empty fields, '.00', odd values),
   so the load never fails on a bad value. Types come later, in core.
*/
USE NYCTaxi;
GO

DROP TABLE IF EXISTS stg.yellow_tripdata;
CREATE TABLE stg.yellow_tripdata (
    VendorID              varchar(10),
    tpep_pickup_datetime  varchar(30),
    tpep_dropoff_datetime varchar(30),
    passenger_count       varchar(10),
    trip_distance         varchar(20),
    RatecodeID            varchar(10),
    store_and_fwd_flag    varchar(5),
    PULocationID          varchar(10),
    DOLocationID          varchar(10),
    payment_type          varchar(10),
    fare_amount           varchar(20),
    extra                 varchar(20),
    mta_tax               varchar(20),
    tip_amount            varchar(20),
    tolls_amount          varchar(20),
    improvement_surcharge varchar(20),
    total_amount          varchar(20),
    congestion_surcharge  varchar(20)
);

DROP TABLE IF EXISTS stg.taxi_zone_lookup;
CREATE TABLE stg.taxi_zone_lookup (
    LocationID   varchar(10),
    Borough      varchar(50),
    Zone         varchar(100),
    service_zone varchar(50)
);
GO
