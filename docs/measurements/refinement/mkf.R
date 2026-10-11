# Ladder with nodes every 1/512 day across a located front.  Rscript mkf.R TAG
tag <- commandArgs(TRUE)[1]; fr <- readRDS(paste0(tag, "_front.rds"))
base <- sort(unique(c(seq(0, 60, by = 2) / 365, seq(0, 53 * 40 / 54, length.out = 54))))
b0 <- (fr$lo + fr$hi) / 2; z <- seq(b0 - 0.03 / 365, b0 + 0.09 / 365, by = 1 / 512 / 365)
clean <- function(v) { v <- sort(unique(v)); v[c(TRUE, diff(v) > 1e-10)] }
bis <- function(v) clean(c(v, head(v, -1) + diff(v) / 2))
l <- clean(c(base, z)); saveRDS(l, paste0(tag, "F.rds")); saveRDS(bis(l), paste0(tag, "F2.rds")); saveRDS(bis(bis(l)), paste0(tag, "F4.rds"))
cat(tag, "front at day", round(365 * b0, 4), "nodes", length(l), length(bis(l)), length(bis(bis(l))), "\n")
