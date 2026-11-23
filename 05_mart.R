# 05_mart.R
#
# Build the tables Tableau reads, and save them as CSV files in output/.
#   mart_no2_hourly    one row per site per hour that has a reading, with everything
#                      the dashboard filters on (season, weekday/weekend, local hour)
#   mart_site_summary  one row per site: name, type, location, average NO2, % missing


library(DBI)

con <- dbConnect(duckdb::duckdb(), "tower_hamlets_no2.duckdb")

dir.create("output", showWarnings = FALSE)

# Joining dimension (site info) and fact (NO2 measures) tables
dbExecute(con, "
  CREATE OR REPLACE TABLE mart_no2_hourly AS
  SELECT h.site_code,
         s.site_name,
         s.site_type,
         CAST(h.measured_at_local AS DATE) AS date,
         strftime(h.measured_at_local, '%H:%M')        AS time_of_day,
         dayname(h.measured_at_local)      AS day_name,
         CASE WHEN isodow(h.measured_at_local) >= 6 THEN 'Weekend'
              ELSE 'Weekday' END           AS day_type,
         CASE WHEN month(h.measured_at_local) IN (12, 1, 2) THEN 'Winter'
              WHEN month(h.measured_at_local) IN (3, 4, 5)  THEN 'Spring'
              WHEN month(h.measured_at_local) IN (6, 7, 8)  THEN 'Summer'
              ELSE 'Autumn' END            AS season,
         h.no2_ugm3
  FROM stg_no2_hourly AS h
  JOIN stg_sites AS s ON h.site_code = s.site_code
  WHERE h.no2_ugm3 IS NOT NULL
")

# For Tableau map location and corresponding avg NO2
# Uses stg_no2_hourly (which still has the missing hours) so pct_missing is correct.
dbExecute(con, "
  CREATE OR REPLACE TABLE mart_site_summary AS
  SELECT s.site_code,
         s.site_name,
         s.site_type,
         s.latitude,
         s.longitude,
         round(avg(h.no2_ugm3), 1)                            AS avg_no2_ugm3,
         count(h.no2_ugm3)                                    AS n_hours_with_value,
         count(*)                                             AS n_hours_total,
         round(100 * (1 - count(h.no2_ugm3) / count(*)), 1)   AS pct_missing
  FROM stg_sites AS s
  JOIN stg_no2_hourly AS h ON h.site_code = s.site_code
  GROUP BY s.site_code, s.site_name, s.site_type, s.latitude, s.longitude
")

# ---- Save for Tableau ---------------------------------------------------------
# COPY writes a table to a file. HEADER puts the column names in the first line.
dbExecute(con, "COPY mart_no2_hourly   TO 'output/mart_no2_hourly.csv'   (HEADER)")
dbExecute(con, "COPY mart_site_summary TO 'output/mart_site_summary.csv' (HEADER)")

# ---- Quick checks ------------------------------------------------------------
dbGetQuery(con, "SELECT * FROM mart_site_summary ORDER BY site_type, avg_no2_ugm3 DESC")

# Rows per season and day type (summer and winter should both be there)
dbGetQuery(con, "
  SELECT season, day_type, count(*) AS n_rows
  FROM mart_no2_hourly
  GROUP BY season, day_type
  ORDER BY season, day_type
")

dbDisconnect(con, shutdown = TRUE)
