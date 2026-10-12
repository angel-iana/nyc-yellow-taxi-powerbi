/* 04 - Lookup tables: codes -> names
   Source: TLC data dictionary for yellow taxi trip records.
*/
USE NYCTaxi;
GO

DROP TABLE IF EXISTS core.vendor;
CREATE TABLE core.vendor (
    vendor_id   tinyint PRIMARY KEY,
    vendor_name varchar(60) NOT NULL
);
INSERT INTO core.vendor VALUES
 (1, 'Creative Mobile Technologies'),
 (2, 'Curb Mobility (VeriFone in 2020)');

DROP TABLE IF EXISTS core.ratecode;
CREATE TABLE core.ratecode (
    ratecode_id   tinyint PRIMARY KEY,
    ratecode_name varchar(40) NOT NULL
);
INSERT INTO core.ratecode VALUES
 (1, 'Standard rate'), (2, 'JFK'), (3, 'Newark'),
 (4, 'Nassau or Westchester'), (5, 'Negotiated fare'),
 (6, 'Group ride'), (99, 'Unknown');

DROP TABLE IF EXISTS core.payment_type;
CREATE TABLE core.payment_type (
    payment_type_id   tinyint PRIMARY KEY,
    payment_type_name varchar(30) NOT NULL
);
INSERT INTO core.payment_type VALUES
 (1, 'Credit card'), (2, 'Cash'), (3, 'No charge'),
 (4, 'Dispute'), (5, 'Unknown'), (6, 'Voided trip');

DROP TABLE IF EXISTS core.zone;
CREATE TABLE core.zone (
    location_id  smallint PRIMARY KEY,
    borough      varchar(50),
    zone         varchar(100),
    service_zone varchar(50)
);
INSERT INTO core.zone (location_id, borough, zone, service_zone)
SELECT TRY_CONVERT(smallint, LocationID), Borough, Zone, service_zone
FROM stg.taxi_zone_lookup;
GO

-- check: 265 zones, 7 boroughs (incl. Unknown and EWR)
SELECT borough, COUNT(*) AS zones
FROM core.zone
GROUP BY borough
ORDER BY zones DESC;
