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
cat("All London sites:", nrow(sites), "\n") # Total number of sites located in london

# Keep sites that are still open (no closing date) 
open_sites <- sites[sites$`@DateClosed` == "",]
cat("Step 1, still open:", nrow(open_sites), "\n") # 72 sites still measuring.

# Site still measuring NO2
open_sites$measures_no2 <- FALSE
for (i in seq_len(nrow(open_sites))) {
  sp <- open_sites$Species[[i]]
  current <- sp$`@SpeciesCode`[sp$`@DateMeasurementFinished` == ""]
  open_sites$measures_no2[i] <- "NO2" %in% current
}
no2_sites <- open_sites[open_sites$measures_no2, ] 
cat("Step 2, still measuring NO2:", nrow(no2_sites), "\n") # 68 sites still measuring NO2

# Sites located in Tower Hamlets
th <- no2_sites[no2_sites$`@LocalAuthorityName` == "Tower Hamlets" |
                startsWith(no2_sites$`@SiteName`, "Tower Hamlets"), ]
cat("Step 3, in Tower Hamlets:", nrow(th), "\n") 
# 6 sites located in Tower Hamlets with 4 Urban Background and 2 Roadside

print(th[, c("@SiteCode", "@SiteName", "@SiteType", "@LocalAuthorityName")], row.names = FALSE)