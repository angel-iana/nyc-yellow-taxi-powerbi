# Data dictionary – NYC yellow taxi trips

Based on the exercise appendix and the NYC Taxi & Limousine Commission (TLC)
[data dictionary for yellow taxi trip records](https://www.nyc.gov/assets/tlc/downloads/pdf/data_dictionary_trip_records_yellow.pdf).
The last column notes what matters for this analysis.

| Column | Meaning | Note for the analysis |
|--------|---------|-----------------------|
| VendorID | Taximeter provider: 1 = Creative Mobile Technologies, 2 = VeriFone | Lookup table for readable names |
| tpep_pickup_datetime | When the meter was switched on | Source for date, weekday and hour |
| tpep_dropoff_datetime | When the meter was switched off | With pickup gives trip duration |
| passenger_count | Number of passengers, entered by the driver | 0 or empty → vehicle type "Unknown" |
| trip_distance | Trip length in miles from the taximeter | 0-mile trips affect tip per mile |
| PULocationID | Taxi zone where the trip started | Joined to the zone lookup (borough, zone) |
| DOLocationID | Taxi zone where the trip ended | Second, inactive relationship to the zone lookup |
| RatecodeID | 1 Standard, 2 JFK, 3 Newark, 4 Nassau/Westchester, 5 Negotiated, 6 Group ride | Airport trips: codes 2 and 3 |
| store_and_fwd_flag | Y = record stored in the vehicle and sent later; N = sent live | Does not affect amounts |
| payment_type | 1 Credit card, 2 Cash, 3 No charge, 4 Dispute, 5 Unknown, 6 Voided | Tips are recorded only for card payments |
| fare_amount | Time-and-distance fare from the meter | Part of driver income |
| extra | Rush-hour and overnight surcharges ($0.50 / $1) | Part of driver income |
| mta_tax | $0.50 MTA tax | Goes to the city, not the driver |
| improvement_surcharge | $0.30 surcharge at flag drop | Goes to the city, not the driver |
| tip_amount | Card tips only; cash tips are not included | Real tips are higher than recorded |
| tolls_amount | Bridge and tunnel tolls paid during the trip | Pass-through cost |
| total_amount | Total charged to the passenger, without cash tips | Shown alongside driver income |

## Derived fields

| Field | Rule |
|-------|------|
| vehicle_type | passenger_count 1–4 Private, 5–6 Medium Car, 7+ Big Car, otherwise Unknown |
| pickup_hour | Hour of the pickup time (10:56 → 10), as in the exercise examples |
| pickup_date, weekday | Date and day name of the pickup, Monday first |
| driver_income | fare_amount + extra + tip_amount |
