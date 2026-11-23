# 01_find_sites.R
#
# Where the site codes in 02_extract.R come from.
# List of monitoring sites that are located in 
# Tower Hamlets which still open and measures NO2.

library(jsonlite)

url <- "https://api.erg.ic.ac.uk/AirQuality/Information/MonitoringSiteSpecies/GroupName=London/Json"

# Download and parse the JSON. The site list sits two levels down:
# { "Sites": { "Site": [ {site 1}, {site 2}, ... ] } }
sites <- fromJSON(url)$Sites$Site      # a data frame, one row per site

# Keep sites that are still open (no closing date) and are named "Tower Hamlets - ...".
# Matching the name, not the borough: CW3 (Jubilee Park) is recorded under Hackney.
th <- sites[sites$`@DateClosed` == "" & startsWith(sites$`@SiteName`, "Tower Hamlets"), ]

print(th[, c("@SiteCode", "@SiteName", "@SiteType", "@LocalAuthorityName")], row.names = FALSE)

# What does each site measure now? (a pollutant with no finish date)
for (i in seq_len(nrow(th))) {
  sp <- th$Species[[i]]
  current <- sp$`@SpeciesCode`[sp$`@DateMeasurementFinished` == ""]
  cat(th$`@SiteCode`[i], "measures now:", current, "\n")
}
