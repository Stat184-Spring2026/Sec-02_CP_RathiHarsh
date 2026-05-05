# STAT 184 - Tech Disruption & Generational Anxiety
# Step 2: Clean and join all data sources
#
# Methodology scaffold adapted from prior project "Breathless"
# (github.com/xyzmr114/breathless), which used a similar
# country-year panel join across WHO/UN/EPA sources.

library(tidyverse)
library(countrycode)

# ---- World Bank: Youth Unemployment -----------------------------------------
youth_unemp <- readRDS("data/youth_unemp_raw.rds") |>
  mutate(iso3c = countrycode(iso2c, "iso2c", "iso3c")) |>
  filter(!is.na(iso3c)) |>
  select(iso3c, year, youth_unemp)

# ---- World Bank: Internet Users ---------------------------------------------
internet <- readRDS("data/internet_raw.rds") |>
  mutate(iso3c = countrycode(iso2c, "iso2c", "iso3c")) |>
  filter(!is.na(iso3c)) |>
  select(iso3c, year, internet)

# ---- World Bank: Fertility --------------------------------------------------
fertility <- readRDS("data/fertility_raw.rds") |>
  mutate(iso3c = countrycode(iso2c, "iso2c", "iso3c")) |>
  filter(!is.na(iso3c)) |>
  select(iso3c, year, fertility)

# ---- IHME GBD: Mental disorder prevalence (combine 2000-2010 + 2011-2023) ---
read_gbd <- function(path) {
  read_csv(path, show_col_types = FALSE) |>
    select(location_name, year, val)
}

mental <- bind_rows(
  read_gbd("data/mental_2000_2010.csv"),
  read_gbd("data/mental_2011_2023.csv")
) |>
  mutate(iso3c = countrycode(location_name, "country.name", "iso3c")) |>
  filter(!is.na(iso3c)) |>
  rename(mental_health = val) |>
  select(iso3c, year, mental_health) |>
  distinct(iso3c, year, .keep_all = TRUE)

# ---- OECD: Real house price index (quarterly -> annual mean) ---------------
housing <- read_csv("data/housing_oecd.csv", show_col_types = FALSE) |>
  select(iso3c = REF_AREA, time_period = TIME_PERIOD, value = OBS_VALUE) |>
  filter(!is.na(value)) |>
  mutate(year = as.integer(str_sub(time_period, 1, 4))) |>
  group_by(iso3c, year) |>
  summarise(house_price = mean(value, na.rm = TRUE), .groups = "drop") |>
  filter(year >= 2000, year <= 2023)

# ---- Merge on iso3c + year --------------------------------------------------
merged <- youth_unemp |>
  left_join(internet,   by = c("iso3c", "year")) |>
  left_join(fertility,  by = c("iso3c", "year")) |>
  left_join(mental,     by = c("iso3c", "year")) |>
  left_join(housing,    by = c("iso3c", "year"))

rm(youth_unemp, internet, fertility, mental, housing)
gc()

# ---- Add continent and income group -----------------------------------------
merged <- merged |>
  mutate(
    continent    = countrycode(iso3c, "iso3c", "continent"),
    income_group = countrycode(iso3c, "iso3c", "wb")
  )

glimpse(merged)
summary(merged)

saveRDS(merged, "data/merged.rds")
write_csv(merged, "data/merged.csv")

message("Step 2 complete. Merged dataset saved to data/merged.rds")
message(paste("Rows:", nrow(merged), "| Countries:", n_distinct(merged$iso3c)))
