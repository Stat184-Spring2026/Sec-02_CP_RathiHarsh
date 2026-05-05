# STAT 184 - Tech Disruption & Generational Anxiety
# Step 3: Analysis and visualization

library(tidyverse)
library(ggcorrplot)

if (!dir.exists("plots")) dir.create("plots")

merged <- readRDS("data/merged.rds")

# ---- 1. Scatter plots: internet vs. each outcome, colored by continent --------

outcome_labels <- c(
  youth_unemp     = "Youth Unemployment (%)",
  fertility       = "Fertility Rate (children per woman)",
  mental_health   = "Mental Disorder Prevalence (%, age-standardized)",
  house_price     = "Real House Price Index (2015 = 100)"
)

scatter_plot <- function(outcome, y_label) {
  merged |>
    filter(!is.na(internet), !is.na(.data[[outcome]])) |>
    ggplot(aes(x = internet, y = .data[[outcome]], color = continent)) +
    geom_point(alpha = 0.35, size = 1.2) +
    geom_smooth(method = "lm", se = TRUE, linewidth = 0.9) +
    scale_color_brewer(palette = "Set1", na.value = "grey60") +
    labs(
      title   = paste("Internet Penetration vs.", y_label),
      x       = "Internet Users (% of population)",
      y       = y_label,
      color   = "Continent",
      caption = "Sources: World Bank WDI, IHME GBD 2023, OECD"
    ) +
    theme_minimal(base_size = 13) +
    theme(legend.position = "bottom")
}

plots_scatter <- imap(outcome_labels, scatter_plot)

iwalk(plots_scatter, \(p, nm) {
  ggsave(paste0("plots/scatter_internet_vs_", nm, ".png"),
         plot = p, width = 8, height = 5.5, dpi = 150)
})

# ---- 2. Correlation heatmap ---------------------------------------------------

cor_data <- merged |>
  select(internet, youth_unemp, fertility, mental_health, house_price) |>
  drop_na()

cor_matrix <- cor(cor_data, use = "complete.obs")

colnames(cor_matrix) <- rownames(cor_matrix) <-
  c("Internet", "Youth\nUnemp.", "Fertility", "Anxiety", "Price/\nIncome")

p_corr <- ggcorrplot(
  cor_matrix,
  method   = "circle",
  type     = "lower",
  lab      = TRUE,
  lab_size = 3.5,
  colors   = c("#E46726", "white", "#6D9EC1"),
  title    = "Correlation Matrix: Internet Penetration & Generational Outcomes",
  ggtheme  = theme_minimal(base_size = 12)
)

ggsave("plots/correlation_heatmap.png", plot = p_corr,
       width = 7, height = 6, dpi = 150)

# ---- 3. Faceted scatter plots by income group --------------------------------

p_facet <- merged |>
  filter(!is.na(income_group)) |>
  pivot_longer(
    cols      = c(youth_unemp, fertility, mental_health, house_price),
    names_to  = "outcome",
    values_to = "value"
  ) |>
  mutate(outcome = recode(outcome, !!!outcome_labels)) |>
  filter(!is.na(internet), !is.na(value)) |>
  ggplot(aes(x = internet, y = value)) +
  geom_point(alpha = 0.25, size = 0.9, color = "steelblue") +
  geom_smooth(method = "lm", se = TRUE, color = "firebrick", linewidth = 0.8) +
  facet_grid(outcome ~ income_group, scales = "free_y") +
  labs(
    title   = "Internet Penetration vs. Outcomes by Income Group",
    x       = "Internet Users (% of population)",
    y       = NULL,
    caption = "Sources: World Bank WDI, IHME GBD 2023, OECD"
  ) +
  theme_bw(base_size = 11) +
  theme(strip.text = element_text(size = 8))

ggsave("plots/faceted_by_income_group.png", plot = p_facet,
       width = 14, height = 10, dpi = 150)

# ---- 4. Simple linear regressions with coefficient plots ---------------------

run_reg <- function(outcome) {
  df <- merged |>
    filter(!is.na(internet), !is.na(.data[[outcome]]))
  lm(reformulate("internet", outcome), data = df)
}

models <- map(names(outcome_labels), run_reg) |>
  setNames(names(outcome_labels))

coef_df <- imap_dfr(models, \(m, nm) {
  ci <- confint(m)["internet", ]
  tibble(
    outcome   = outcome_labels[[nm]],
    estimate  = coef(m)["internet"],
    lower_95  = ci[1],
    upper_95  = ci[2],
    p_value   = summary(m)$coefficients["internet", "Pr(>|t|)"]
  )
})

p_coef <- coef_df |>
  mutate(
    sig     = p_value < 0.05,
    outcome = fct_reorder(outcome, estimate)
  ) |>
  ggplot(aes(x = estimate, y = outcome, color = sig)) +
  geom_vline(xintercept = 0, linetype = "dashed", color = "grey50") +
  geom_errorbarh(aes(xmin = lower_95, xmax = upper_95), height = 0.25) +
  geom_point(size = 3.5) +
  scale_color_manual(
    values = c("TRUE" = "#d62728", "FALSE" = "#7f7f7f"),
    labels = c("TRUE" = "p < 0.05", "FALSE" = "p >= 0.05")
  ) +
  labs(
    title   = "OLS Coefficients: Effect of Internet Penetration on Each Outcome",
    x       = "Coefficient (per 1 pp increase in internet users)",
    y       = NULL,
    color   = NULL,
    caption = "95% confidence intervals shown. Sources: World Bank WDI, IHME GBD 2023, OECD"
  ) +
  theme_minimal(base_size = 13) +
  theme(legend.position = "bottom")

ggsave("plots/coefficient_plot.png", plot = p_coef,
       width = 9, height = 5, dpi = 150)

# ---- 5. Hero visualization: four-panel story ---------------------------------

library(patchwork)

make_hero_panel <- function(outcome, y_label, color_hex) {
  merged |>
    filter(!is.na(internet), !is.na(.data[[outcome]])) |>
    ggplot(aes(x = internet, y = .data[[outcome]])) +
    geom_point(alpha = 0.2, size = 0.8, color = color_hex) +
    geom_smooth(method = "lm", se = TRUE,
                color = color_hex, fill = color_hex, alpha = 0.2,
                linewidth = 1) +
    labs(title = y_label, x = NULL, y = NULL) +
    theme_minimal(base_size = 11) +
    theme(plot.title = element_text(size = 10, face = "bold"))
}

panel_colors <- c("#e41a1c", "#377eb8", "#4daf4a", "#984ea3")

hero_panels <- list(
  make_hero_panel("youth_unemp",     outcome_labels["youth_unemp"],     panel_colors[1]),
  make_hero_panel("fertility",       outcome_labels["fertility"],       panel_colors[2]),
  make_hero_panel("mental_health",         outcome_labels["mental_health"],         panel_colors[3]),
  make_hero_panel("house_price", outcome_labels["house_price"], panel_colors[4])
)

p_hero <- wrap_plots(hero_panels, ncol = 2) +
  plot_annotation(
    title    = "As Countries Go Online: Four Generational Pressures",
    subtitle = "Each point is one country-year (2000-2023). Lines are OLS fits.",
    caption  = "Sources: World Bank WDI, IHME GBD 2023, OECD",
    theme    = theme(
      plot.title    = element_text(size = 16, face = "bold"),
      plot.subtitle = element_text(size = 11, color = "grey40")
    )
  )

ggsave("plots/hero_visualization.png", plot = p_hero,
       width = 12, height = 8, dpi = 150)

message("Step 3 complete. All plots saved to plots/")
print(coef_df)
