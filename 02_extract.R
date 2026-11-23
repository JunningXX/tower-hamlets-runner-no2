# 02_extract.R
#
# Download hourly NO2 readings for six Tower Hamlets monitoring sites from the
# London Air Quality Network API (https://api.erg.ic.ac.uk/AirQuality/Help)
# Every response is saved to data/raw/ exactly as it came back.
#
# One file per site per day. A day is only downloaded once it has finished,
# so each run asks only for the days that are not saved yet.


# Load packages
library(httr2)

# ---- Settings ---------------------------------------------------------------
# Site codes chosen with 01_find_sites.R: the open Tower Hamlets sites
# that still measure NO2.
sites <- c("TH2", "TH4", "TH5", "TH6", "TH7", "CW3")

first_day <- as.Date("2026-01-01")   # first day of history to collect
last_day  <- Sys.Date() - 1          # yesterday: the last day that has finished

days <- seq(first_day, last_day, by = "day")

dir.create("data/raw/no2", recursive = TRUE, showWarnings = FALSE)
dir.create("data/raw/metadata", recursive = TRUE, showWarnings = FALSE)

# ---- Dimension table ------------------------------------
# Contains site type and location
meta_path <- "data/raw/metadata/site_species.json"
if (!file.exists(meta_path)) {
  resp <- request("https://api.erg.ic.ac.uk/AirQuality") |>
    req_url_path_append("Information", "MonitoringSiteSpecies",
                        "GroupName=London", "Json") |>
    req_retry(max_tries = 5) |>
    req_perform()
  writeBin(resp_body_raw(resp), meta_path)
  message("Saved: ", meta_path)
}

# ---- Fact table ----------------------------------------
# Loop over 6 sites, one folder per site
for (site in sites) {
  site_dir <- file.path("data/raw/no2", site)     # one folder per site
  dir.create(site_dir, recursive = TRUE, showWarnings = FALSE)

  for (i in seq_along(days)) {
    day <- days[i]

  # In R a Date is stored as the number of days since 1970-01-01.
  # A for loop over a Date vector drops the Date class, so
  # `for (day in days)` would give 20778 instead of "2026-11-21",
  # and the URL, the file name and `day + 1` would all be wrong.
  # Looping over positions 1, 2, 3, ... and taking days[i] keeps the Date class.

    file_path <- file.path(site_dir,
                           paste0(site, "_", format(day, "%Y-%m-%d"), ".json"))

    # Raw files are never overwritten: once a day is saved, skip it.
    if (file.exists(file_path)) next

    resp <- request("https://api.erg.ic.ac.uk/AirQuality") |>
      req_url_path_append("Data", "SiteSpecies",
                          paste0("SiteCode=", site),
                          "SpeciesCode=NO2",
                          paste0("StartDate=", day),
                          paste0("EndDate=", day + 1),   # EndDate is not included
                          "Json") |>
      req_retry(max_tries = 5) |>      
      req_perform()                    

    # Save the bytes exactly as received: no parsing, no reformatting.
    writeBin(resp_body_raw(resp), file_path)
    message("Saved: ", file_path)

    Sys.sleep(0.5) # pause between requests to be kind to the API
  }
}