# The synthetic 41-year daily rainfall record (harness/long_drought.R, the
# "long-drought" spec): writes record.csv on first run, then the figure.
#   PLANT_LIB=<any plant library> Rscript record.R
library(ggplot2)
here <- "/home/user/plant-dev/docs/prs/v2/figures/plant-115"
csv <- file.path(here, "record.csv")
if (!file.exists(csv)) {
  source("/home/user/plant-dev/harness/long_drought.R")
  r <- rain_record("long-drought")
  write.csv(data.frame(day = seq_along(r) - 1, year = (seq_along(r) - 1) %/% 365 + 1,
                       rain_m_per_yr = r), csv, row.names = FALSE)
}
d <- read.csv(csv)
y <- aggregate(rain_m_per_yr ~ year, d, mean)
y$wet_days <- aggregate(rain_m_per_yr > 0 ~ year, d, mean)[[2]]
y$kind <- ifelse(y$year %in% c(8:10, 19:22, 32:34), "drought", "ordinary")
grp <- list(8:10, 19:22, 32:34)
lab <- data.frame(x = sapply(grp, mean),
                  y = sapply(grp, function(g) max(y$rain_m_per_yr[y$year %in% g])) + 0.25,
                  label = c("years 8-10", "years 19-22", "years 32-34"))
p <- ggplot(y, aes(year, rain_m_per_yr, fill = kind)) +
  geom_col(width = 0.85) +
  geom_text(data = lab, aes(x, y, label = label), inherit.aes = FALSE,
            vjust = 0, size = 3.6, colour = "#D55E00") +
  geom_hline(yintercept = mean(d$rain_m_per_yr), linetype = 2, colour = "grey40") +
  annotate("text", x = 41.6, y = mean(d$rain_m_per_yr), label = "mean 3.0",
           hjust = 0, vjust = -0.4, size = 3.4, colour = "grey30") +
  scale_fill_manual(values = c(drought = "#D55E00", ordinary = "#56B4E9"), guide = "none") +
  scale_x_continuous(breaks = c(1, 10, 20, 30, 40), expand = expansion(add = c(0.5, 3))) +
  labs(x = "year of the record", y = expression("mean rainfall (m yr"^-1*")"),
       title = "Three multi-year droughts in 41 years of daily rain",
       subtitle = paste("14 965 days; wet days from a seasonal Markov chain, gamma depths,",
                        "\neach year's depths scaled (orange: by 0.28-0.55)")) +
  theme_minimal(base_size = 12) + theme(plot.background = element_rect(fill = "white", colour = NA), plot.title.position = "plot")
ragg::agg_png(file.path(here, "record.png"), width = 8, height = 4.5, units = "in", res = 200)
print(p); invisible(dev.off())
cat(sprintf("days %d, mean %.3f, wet-day share %.3f, drought-year means %s\n", nrow(d),
            mean(d$rain_m_per_yr), mean(d$rain_m_per_yr > 0),
            paste(sprintf("%.2f", y$rain_m_per_yr[y$kind == "drought"]), collapse = " ")))
