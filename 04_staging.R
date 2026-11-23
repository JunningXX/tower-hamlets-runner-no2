# 04_staging.R
#
# Turn the raw tables into clean tables that are easy to query.
#   stg_no2_hourly  one row per site per hour 
#   stg_sites       one row per site we collect, with its name, type and location
 
library(DBI)
 
con <- dbConnect(duckdb::duckdb(), "tower_hamlets_no2.duckdb")

# icu extension handles time zones
dbExecute(con, "INSTALL icu")
dbExecute(con, "LOAD icu")
 
# Build the staging table: one clean row per hour
dbExecute(con, "
  CREATE OR REPLACE TABLE stg_no2_hourly AS
  WITH hours AS (
    SELECT RawAQData['@SiteCode']    AS site_code,
           RawAQData['@SpeciesCode'] AS species_code,
           unnest(RawAQData.Data)    AS h
    FROM raw_no2
  )
  SELECT DISTINCT
         site_code,
         species_code,
         h['@MeasurementDateGMT'] AS measured_at_gmt,
         timezone('Europe/London', timezone('UTC', h['@MeasurementDateGMT'])) AS measured_at_local,
         TRY_CAST(NULLIF(h['@Value'], '') AS DOUBLE) AS no2_ugm3
  FROM hours
")

# extract site details 
dbExecute(con, "
  CREATE OR REPLACE TABLE stg_sites AS
  WITH sites AS (
    SELECT unnest(Sites.Site) AS s
    FROM raw_site_species
  )
  SELECT s['@SiteCode']                      AS site_code,
         trim(s['@SiteName'])                AS site_name,
         s['@SiteType']                      AS site_type,
         s['@LocalAuthorityName']            AS local_authority,
         CAST(s['@Latitude']  AS DOUBLE) AS latitude,
         CAST(s['@Longitude'] AS DOUBLE) AS longitude
  FROM sites
  WHERE s['@SiteCode'] IN (SELECT DISTINCT site_code FROM stg_no2_hourly)
")

# Quick checks
# The six sites, with their type (Roadside or Urban Background)
dbGetQuery(con, "SELECT * FROM stg_sites ORDER BY site_type, site_code")

# Hours per site, and how many hours have no reading
dbGetQuery(con, "
  SELECT site_code,
         count(*)                                         AS n_hours,
         count(no2_ugm3)                                  AS n_with_value,
         round(100 * (1 - count(no2_ugm3) / count(*)), 1) AS pct_missing
  FROM stg_no2_hourly
  GROUP BY site_code
  ORDER BY site_code
")

# Summer time check: in June, 01:00 GMT should show as 02:00 local
dbGetQuery(con, "
  SELECT site_code, measured_at_gmt, measured_at_local, no2_ugm3
  FROM stg_no2_hourly
  WHERE site_code = 'TH2'
    AND measured_at_gmt BETWEEN '2026-06-01 00:00' AND '2026-06-01 03:00'
  ORDER BY measured_at_gmt
")

dbDisconnect(con, shutdown = TRUE)