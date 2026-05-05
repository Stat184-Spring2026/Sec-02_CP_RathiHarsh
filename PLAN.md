# Project Plan

This file documents the plan and PCIP (Plan / Code / Improve / Polish)
cycles for the project. It is the supporting evidence for the
"applies the PCIP system" learning outcome.

## Question

As internet penetration rises across countries (2000-2023), what
happens to four generational outcomes: youth unemployment, fertility,
mental disorder prevalence, and housing affordability? Do the surface
patterns survive country and year fixed effects?

## Paradigm

Exploratory Data Analysis using the tidyverse. Goal is description and
hypothesis generation, not confirmatory testing. Choice rationale lives
in the report's Introduction.

## PCIP cycles

### Cycle 1: data acquisition (`R/01_acquire.R`)

- **Plan.** Pull WB WDI series (`IT.NET.USER.ZS`, `SL.UEM.1524.ZS`,
  `SP.DYN.TFRT.IN`) through the `{WDI}` package; pull OECD
  `HH_DASH` through `{OECD}`; pull IHME GBD anxiety/mental disorder
  prevalence as CSV from the GBD Results Tool.
- **Code.** Wrote one acquisition script that saves each indicator to
  `data/*_raw.rds` so downstream scripts do not depend on network.
- **Improve.** First pass had a single GBD CSV that hit the row cap.
  Split the request in two (2000-2010, 2011-2023) and combined in
  Step 2.
- **Polish.** Added a check that `data/` exists before saving; added a
  short header comment to each script saying what it does and what it
  produces.

### Cycle 2: clean and join (`R/02_clean_join.R`)

- **Plan.** Harmonise country codes to ISO-3166 alpha-3 with
  `{countrycode}`, drop rows with no resolvable code (mostly regional
  aggregates), aggregate OECD quarterly data to annual means, then
  inner-join on `(iso3c, year)`.
- **Code.** Built five small cleaning blocks (one per source) feeding a
  single `left_join` chain on the WDI panel.
- **Improve.** First pass dropped IHME duplicates the wrong way; fixed
  by `distinct(iso3c, year, .keep_all = TRUE)` after
  `countrycode` resolution.
- **Polish.** Added `glimpse()` and `summary()` of the merged panel as
  the last step so anyone re-running the script sees the shape.

### Cycle 3: visualise and analyse (`R/03_analyze_visualize.R`)

- **Plan.** Five visuals: per-outcome scatter coloured by continent,
  correlation heatmap, faceted-by-income-group panel, OLS coefficient
  plot, and a four-panel "hero" summary.
- **Code.** Built each plot independently and saved to `plots/`.
- **Improve.** First hero plot used absolute axes with no clipping;
  outliers in `youth_unemp` and `house_price` were dragging the panels.
  Added `coord_cartesian(ylim = ...)` to keep the loess shape readable
  without dropping the data.
- **Polish.** Added `caption =` lines naming the data sources on every
  exported plot.

### Cycle 4: education channel and FE (`R/04_causal_education.R`)

- **Plan.** Add three controls (log GDP per capita, tertiary
  enrollment, urbanisation) and a two-way fixed-effects
  specification. Compare the coefficient on `internet` across three
  nested models. Then check whether faceting by tertiary-education tier
  flattens the headline slopes.
- **Code.** Wrote `run_nested()` so the nested-model logic is the same
  for every outcome; ran a small mediation table for the education
  channel.
- **Improve.** First fixed-effects model used `country` (the WB string
  name) instead of `iso3c`; some country names changed across years
  (e.g. "Türkiye" vs "Turkey") and the FE design matrix was confused.
  Switched to `iso3c` factor.
- **Polish.** Recoded outcome labels with a single named vector so the
  facet titles in `causal_nested_models.png` read cleanly.

### Cycle 5: report (`report.qmd`)

- **Plan.** Self-contained QMD that loads the cleaned panel, redoes
  every visualisation in chunks (so figures are tracked by `knitr`),
  and includes a code appendix via `ref.label = knitr::all_labels()`.
  Body has only narrative; code lives only in chunks and the appendix.
- **Code.** Drafted in seven sections: intro, data, descriptive stats,
  visualisations, discussion, contributions, references.
- **Improve.** First draft had inline code summaries that pushed code
  into the body; moved everything into chunks with `echo: false` and
  added the `code-appendix` chunk at the end.
- **Polish.** Added `fig-cap` and `fig-alt` for every figure; added
  `tbl-cap` for both tables; added cross-references with
  `@fig-...` / `@tbl-...`; added `bibliography:` + APA7 CSL for
  citations.

## Repository plan

- `main` branch holds the rendered report and stable code.
- `dev-harsh` branch is where work happens; merged to `main` through a
  Pull Request reviewed by another collaborator.
- Issues track outstanding tasks (data acquisition, plot revisions,
  FAIR/CARE writeup, render to PDF).
- Commits are small and have plain imperative subjects.
- The repo contains everything needed to reproduce: scripts, data,
  plots, the QMD, the rendered PDF, the bibliography, and the CSL files.
