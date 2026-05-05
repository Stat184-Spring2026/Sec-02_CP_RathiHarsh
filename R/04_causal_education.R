# STAT 184 - Step 4: toward causal inference + education channel
#
# Adds three controls from World Bank WDI: GDP per capita, tertiary
# education enrollment, urbanization. Runs a two-way fixed-effects
# panel regression (country + year FEs) and a nested model comparison
# to ask: does the internet-outcome relationship survive controls?
# Then a focused education channel analysis.

suppressPackageStartupMessages({
  library(tidyverse)
  library(WDI)
  library(countrycode)
  library(patchwork)
})

# Run from the repo root; data/ and plots/ are relative to it.

# ---- Pull additional WDI controls -------------------------------------------
controls <- WDI(
  indicator = c(
    gdp_pc      = "NY.GDP.PCAP.KD",
    tertiary_ed = "SE.TER.ENRR",
    urban_pct   = "SP.URB.TOTL.IN.ZS"
  ),
  start = 2000, end = 2023, extra = FALSE
) |>
  mutate(iso3c = countrycode(iso2c, "iso2c", "iso3c", warn = FALSE)) |>
  filter(!is.na(iso3c)) |>
  select(iso3c, year, gdp_pc, tertiary_ed, urban_pct)

saveRDS(controls, "data/controls_raw.rds")

# ---- Merge with existing panel ----------------------------------------------
merged <- readRDS("data/merged.rds") |>
  left_join(controls, by = c("iso3c", "year"))

saveRDS(merged, "data/merged_with_controls.rds")
write_csv(merged, "data/merged_with_controls.csv")

cat(sprintf("Panel with controls: %d rows | %d countries\n",
            nrow(merged), n_distinct(merged$iso3c)))

# =============================================================================
# A. NESTED REGRESSION: does internet still matter after controls + FEs?
# =============================================================================

run_nested <- function(outcome) {
  df <- merged |>
    filter(!is.na(internet),
           !is.na(.data[[outcome]]),
           !is.na(gdp_pc), !is.na(tertiary_ed), !is.na(urban_pct)) |>
    mutate(
      country_f = factor(iso3c),
      year_f    = factor(year),
      log_gdp   = log(gdp_pc)
    )

  m1 <- lm(reformulate("internet", outcome), data = df)
  m2 <- lm(reformulate(c("internet", "log_gdp", "tertiary_ed", "urban_pct"),
                       outcome), data = df)
  m3 <- lm(reformulate(c("internet", "log_gdp", "tertiary_ed", "urban_pct",
                         "country_f", "year_f"),
                       outcome), data = df)

  bind_rows(
    tibble(model = "1: bivariate",            outcome = outcome,
           estimate = coef(m1)["internet"],
           se = sqrt(diag(vcov(m1)))["internet"],
           n = nobs(m1)),
    tibble(model = "2: + GDP, ed, urban",    outcome = outcome,
           estimate = coef(m2)["internet"],
           se = sqrt(diag(vcov(m2)))["internet"],
           n = nobs(m2)),
    tibble(model = "3: + country & year FE", outcome = outcome,
           estimate = coef(m3)["internet"],
           se = sqrt(diag(vcov(m3)))["internet"],
           n = nobs(m3))
  )
}

nested_results <- map_dfr(
  c("youth_unemp", "fertility", "mental_health", "house_price"),
  run_nested
) |>
  mutate(
    lower_95 = estimate - 1.96 * se,
    upper_95 = estimate + 1.96 * se,
    sig      = (lower_95 > 0) | (upper_95 < 0)
  )

write_csv(nested_results, "data/nested_regression_results.csv")
cat("\nNested regression results:\n")
print(nested_results)

# Visualize how internet's coefficient changes as we add controls + FEs
outcome_labels <- c(
  youth_unemp   = "Youth Unemployment",
  fertility     = "Fertility",
  mental_health = "Mental Disorders",
  house_price   = "House Price Index"
)

p_nested <- nested_results |>
  mutate(outcome = recode(outcome, !!!outcome_labels)) |>
  ggplot(aes(x = estimate, y = fct_rev(model), color = sig)) +
  geom_vline(xintercept = 0, linetype = "dashed", color = "grey50") +
  geom_errorbarh(aes(xmin = lower_95, xmax = upper_95), height = 0.2) +
  geom_point(size = 3) +
  scale_color_manual(values = c("TRUE" = "#d62728", "FALSE" = "#7f7f7f"),
                     labels = c("TRUE" = "p < 0.05", "FALSE" = "n.s.")) +
  facet_wrap(~ outcome, scales = "free_x") +
  labs(
    title = "Toward causal inference: internet coefficient shrinks but mostly survives",
    subtitle = "Model 1: internet only. Model 2: + log(GDP), tertiary ed, urbanization. Model 3: + country & year fixed effects.",
    x = "Coefficient on internet penetration (per 1 pp)",
    y = NULL, color = NULL,
    caption = "WB WDI, IHME GBD 2023, OECD. Two-way FE absorbs time-invariant country traits and global year shocks."
  ) +
  theme_minimal(base_size = 11) +
  theme(legend.position = "bottom",
        strip.text = element_text(face = "bold"))

ggsave("plots/causal_nested_models.png", plot = p_nested,
       width = 12, height = 7, dpi = 150)

# =============================================================================
# B. EDUCATION CHANNEL: is education driving mental health & fertility?
# =============================================================================

ed_data <- merged |>
  filter(!is.na(internet), !is.na(tertiary_ed),
         !is.na(mental_health), !is.na(fertility)) |>
  mutate(ed_tier = case_when(
    tertiary_ed < 30  ~ "Low (<30%)",
    tertiary_ed < 60  ~ "Mid (30-60%)",
    TRUE              ~ "High (60%+)"
  ),
  ed_tier = factor(ed_tier, levels = c("Low (<30%)","Mid (30-60%)","High (60%+)")))

# B1: scatter of internet vs mental health, faceted by education tier
p_ed_mental <- ed_data |>
  ggplot(aes(x = internet, y = mental_health)) +
  geom_point(alpha = 0.3, size = 1, color = "#4daf4a") +
  geom_smooth(method = "lm", color = "#1b5e20", se = TRUE, linewidth = 1) +
  facet_wrap(~ ed_tier, nrow = 1) +
  labs(
    title = "Mental health prevalence vs. internet, split by tertiary education",
    subtitle = "If education were the real driver, the slope would flatten in the high-ed panel. It does not.",
    x = "Internet Users (% of population)",
    y = "Mental Disorder Prevalence (%, age-standardized)",
    caption = "WB WDI, IHME GBD 2023. Education = gross tertiary enrollment ratio."
  ) +
  theme_minimal(base_size = 12) +
  theme(strip.text = element_text(face = "bold"))

ggsave("plots/education_mental_health.png", plot = p_ed_mental,
       width = 12, height = 5, dpi = 150)

# B2: same for fertility
p_ed_fert <- ed_data |>
  ggplot(aes(x = internet, y = fertility)) +
  geom_point(alpha = 0.3, size = 1, color = "#377eb8") +
  geom_smooth(method = "lm", color = "#0d47a1", se = TRUE, linewidth = 1) +
  facet_wrap(~ ed_tier, nrow = 1) +
  labs(
    title = "Fertility vs. internet, split by tertiary education",
    subtitle = "Fertility decline is steepest in low-education countries, suggesting internet & education co-drive the decline.",
    x = "Internet Users (% of population)",
    y = "Fertility Rate (children per woman)",
    caption = "WB WDI. Education = gross tertiary enrollment ratio."
  ) +
  theme_minimal(base_size = 12) +
  theme(strip.text = element_text(face = "bold"))

ggsave("plots/education_fertility.png", plot = p_ed_fert,
       width = 12, height = 5, dpi = 150)

# B3: education's own effect, holding internet constant (added-variable plot)
mediation_models <- list(
  mental_no_ed   = lm(mental_health ~ internet,                       data = ed_data),
  mental_with_ed = lm(mental_health ~ internet + tertiary_ed,         data = ed_data),
  fert_no_ed     = lm(fertility ~ internet,                           data = ed_data),
  fert_with_ed   = lm(fertility ~ internet + tertiary_ed,             data = ed_data)
)

mediation_table <- imap_dfr(mediation_models, \(m, nm) {
  tibble(
    model = nm,
    internet_coef     = coef(m)["internet"],
    tertiary_ed_coef  = if ("tertiary_ed" %in% names(coef(m))) coef(m)["tertiary_ed"] else NA_real_,
    n = nobs(m)
  )
})

write_csv(mediation_table, "data/education_mediation.csv")
cat("\nEducation mediation table:\n")
print(mediation_table)

# =============================================================================
# C. REFINED HERO PLOT (loess + tighter youth-unemp axis)
# =============================================================================

make_hero_v2 <- function(outcome, y_label, color_hex, ylim_pair = NULL) {
  p <- merged |>
    filter(!is.na(internet), !is.na(.data[[outcome]])) |>
    ggplot(aes(x = internet, y = .data[[outcome]])) +
    geom_point(alpha = 0.15, size = 0.7, color = color_hex) +
    geom_smooth(method = "loess", se = TRUE, span = 0.7,
                color = color_hex, fill = color_hex, alpha = 0.25,
                linewidth = 1.1) +
    geom_smooth(method = "lm", se = FALSE,
                color = "black", linetype = "dashed", linewidth = 0.7) +
    labs(title = y_label, x = NULL, y = NULL) +
    theme_minimal(base_size = 11) +
    theme(plot.title = element_text(size = 10, face = "bold"))
  if (!is.null(ylim_pair)) p <- p + coord_cartesian(ylim = ylim_pair)
  p
}

panel_colors <- c("#e41a1c", "#377eb8", "#4daf4a", "#984ea3")

hero_v2 <- list(
  make_hero_v2("youth_unemp",   "Youth Unemployment (%)",
               panel_colors[1], ylim_pair = c(0, 50)),
  make_hero_v2("fertility",     "Fertility Rate (children per woman)",
               panel_colors[2]),
  make_hero_v2("mental_health", "Mental Disorder Prevalence (%, age-std)",
               panel_colors[3]),
  make_hero_v2("house_price",   "Real House Price Index (2015 = 100)",
               panel_colors[4], ylim_pair = c(40, 200))
)

p_hero2 <- wrap_plots(hero_v2, ncol = 2) +
  plot_annotation(
    title    = "As Countries Go Online: Four Generational Pressures",
    subtitle = "Solid line = loess (local trend). Dashed = OLS. Country-years 2000-2023.",
    caption  = "Sources: World Bank WDI, IHME GBD 2023, OECD",
    theme = theme(
      plot.title    = element_text(size = 16, face = "bold"),
      plot.subtitle = element_text(size = 11, color = "grey40")
    )
  )

ggsave("plots/hero_visualization_v2.png", plot = p_hero2,
       width = 12, height = 8, dpi = 150)

cat("\nDone. New plots in plots/: causal_nested_models.png, education_mental_health.png, education_fertility.png, hero_visualization_v2.png\n")
