# data/

Raw inputs and derived panels. All files are produced by the scripts at the repo root; nothing here is hand-edited.

## Raw (from sources)

| File | Source | Notes |
|---|---|---|
| `internet_raw.rds` | WDI `IT.NET.USER.ZS` | Internet users, % of pop |
| `youth_unemp_raw.rds` | WDI `SL.UEM.1524.ZS` | Youth unemployment 15-24 |
| `fertility_raw.rds` | WDI `SP.DYN.TFRT.IN` | Fertility rate |
| `controls_raw.rds` | WDI `NY.GDP.PCAP.KD`, `SE.TER.ENRR`, `SP.URB.TOTL.IN.ZS` | GDP/cap, tertiary enrollment, urbanization |
| `mental_2000_2010.csv`, `mental_2011_2023.csv` | IHME GBD 2023 | Mental disorders, prevalence, age-standardized. Manual download from healthdata.org/gbd-results |
| `housing_oecd.csv` | OECD | Real House Price Index, quarterly |

## Derived (produced by the pipeline)

| File | Produced by | Notes |
|---|---|---|
| `merged.rds`, `merged.csv` | `02_clean_join.R` / `run_all.R` | Country-year panel: internet + 4 outcomes + continent + income group |
| `merged_with_controls.rds`, `merged_with_controls.csv` | `04_causal_education.R` | Adds GDP/cap, tertiary enrollment, urbanization |
| `nested_regression_results.csv` | `04_causal_education.R` | Internet coefficients across bivariate / +controls / +country&year FE specs |
| `education_mediation.csv` | `04_causal_education.R` | Internet & tertiary education coefficients with and without each other |
