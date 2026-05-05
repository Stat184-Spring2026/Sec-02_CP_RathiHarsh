# STAT 184 - Tech Disruption & Generational Pressures
# Step 1: Acquire all data programmatically (no manual CSV downloads)
#
# Required packages (install once before running):
#   install.packages(c("WDI", "tidyverse", "countrycode",
#                      "ggcorrplot", "OECD", "patchwork"))

library(WDI)
library(tidyverse)
library(countrycode)
library(OECD)

if (!dir.exists("data")) dir.create("data")

# ---- World Bank: Youth Unemployment (ages 15-24, % of labor force) ----------
youth_unemp <- WDI(
  indicator = "SL.UEM.1524.ZS",
  start = 2000, end = 2023,
  extra = FALSE
) |>
  select(iso2c, country, year, youth_unemp = SL.UEM.1524.ZS)

saveRDS(youth_unemp, "data/youth_unemp_raw.rds")
rm(youth_unemp); gc()

# ---- World Bank: Internet Users (% of population) ---------------------------
internet <- WDI(
  indicator = "IT.NET.USER.ZS",
  start = 2000, end = 2023,
  extra = FALSE
) |>
  select(iso2c, country, year, internet = IT.NET.USER.ZS)

saveRDS(internet, "data/internet_raw.rds")
rm(internet); gc()

# ---- World Bank: Fertility rate (births per woman) --------------------------
# SP.DYN.TFRT.IN is the same underlying series OWID uses
fertility <- WDI(
  indicator = "SP.DYN.TFRT.IN",
  start = 2000, end = 2023,
  extra = FALSE
) |>
  select(iso2c, country, year, fertility = SP.DYN.TFRT.IN)

saveRDS(fertility, "data/fertility_raw.rds")
rm(fertility); gc()

# ---- GBD: Anxiety disorder prevalence --------------------------------------
# Manually download from healthdata.org/research-analysis/gbd-results
# Filters: Cause=Anxiety disorders, Measure=Prevalence, Metric=Percent,
#          Location=all countries, Age=Age-standardized, Sex=Both, Year=2000-2023
# Save file as data/anxiety.csv - loaded directly in 02_clean_join.R

# ---- OECD: Housing price-to-income ratio ------------------------------------
# Dataset "HH_DASH" contains the "HPRI" (house price-to-income ratio) series.
# get_dataset() returns a tidy data frame with LOCATION, Time, ObsValue, etc.
housing_raw <- OECD::get_dataset(
  dataset    = "HH_DASH",
  filter     = list(indicator = "HPRI"),
  start_time = 2000,
  end_time   = 2023
)

saveRDS(housing_raw, "data/housing_raw.rds")
rm(housing_raw); gc()

message("Step 1 complete. All raw data saved to data/")
