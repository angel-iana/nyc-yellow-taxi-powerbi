/* 01 - Create the NYCTaxi database and its schemas
   Purpose: check and understand the data in SQL. Power BI reads the CSV files directly;
   this database is only used to verify the numbers independently.
   stg  = raw data, exactly as in the CSV files (all text)
   core = typed data with derived columns and an exclude_reason flag
*/
USE master;
GO

IF DB_ID('NYCTaxi') IS NULL
    CREATE DATABASE NYCTaxi;
GO

-- simple recovery: no big log file for a practice database
ALTER DATABASE NYCTaxi SET RECOVERY SIMPLE;
GO

USE NYCTaxi;
GO

IF SCHEMA_ID('stg')  IS NULL EXEC('CREATE SCHEMA stg');
IF SCHEMA_ID('core') IS NULL EXEC('CREATE SCHEMA core');
GO

SELECT name AS schema_name FROM sys.schemas WHERE name IN ('stg','core');
