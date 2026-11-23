# 03_load.R
#
# Load the raw JSON files in data/raw/ into DuckDB, unchanged.
#   raw_no2           one row per file (one site-day), as the API returned it
#   raw_site_species  the site details file, as the API returned it
# Safe to re-run: CREATE OR REPLACE rebuilds both tables from the files every time,
# so the database always matches what is in data/raw/.

library(DBI)

# Connect to the DuckDB database file (created if it does not exist yet)
con <- dbConnect(duckdb::duckdb(), "tower_hamlets_no2.duckdb")

# Stack all JSON files into one table, one row per file,
# data/raw/no2/*/*.json = every file in every site folder.
# filename = true adds a column saying which file each row came from.
dbExecute(con, "
  CREATE OR REPLACE TABLE raw_no2 AS
  SELECT filename,
         RawAQData
  FROM read_json('data/raw/no2/*/*.json', filename = true)
")

# Create another table to store site information
# One JSON file only, no need for filename
dbExecute(con, "
  CREATE OR REPLACE TABLE raw_site_species AS
  SELECT Sites
  FROM read_json('data/raw/metadata/site_species.json')
")

# Quick checks 
dbListTables(con)

# Files per site, and the first and last day loaded
# Date of the last_file should be yesterday's date.
dbGetQuery(con, "
  SELECT RawAQData['@SiteCode'] AS site_code,
         count(*)               AS n_files,
         min(filename)          AS first_file,
         max(filename)          AS last_file
  FROM raw_no2
  GROUP BY site_code
  ORDER BY site_code
")

# Every file should hold 24 hours
dbGetQuery(con, "
  SELECT len(RawAQData.Data) AS hours_in_file, count(*) AS n_files
  FROM raw_no2
  GROUP BY hours_in_file
")

# Close the connection and release the lock on the database file
dbDisconnect(con, shutdown = TRUE)
