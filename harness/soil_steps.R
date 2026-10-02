# Which component bounds each accepted step of a harness/ark_prototype.R run, on
# the rain intervals and the dry ones; for the soil-bound steps inside an
# interval, their error ratio and the next step's growth; and the steps per
# interval, with those in its first day.
#
#   Rscript harness/soil_steps.R run.rds [run2.rds ...]
#
# A run saved before the driver kept its record's rain and knots is long
# drought's.
here <- tryCatch(dirname(sys.frame(1)$ofile), error = function(e) "harness")
ld <- readRDS(file.path(here, "..", "docs", "measurements", "spot-check", "ld_3e-5.rds"))
DAY <- 1 / 365
NODE <- c("height", "mortality", "fecundity", "area_heartwood", "mass_heartwood",
          "storage", "offspring", "log_density", "mass")
ENV <- c(paste0("soil_", 1:5), paste0("accumulator_", 1:5))
for (f in commandArgs(TRUE)) {
  x <- readRDS(f)
  st <- x$st
  knots <- sort(unique(if (is.null(x$knots)) ld$knots else x$knots))
  rain <- if (is.null(x$rain)) ld$rain else x$rain
  rain_at <- function(t) rain[pmin(pmax(floor(t / DAY + 1e-9) + 1, 1), length(rain))]
  t0 <- st$time - st$h
  iv <- findInterval(t0 + 1e-12, knots)
  since <- (t0 - ifelse(iv > 0, knots[pmax(iv, 1)], 0)) / DAY
  wet <- rain_at(t0 + st$h / 2) > 0
  part <- ifelse(st$ei <= 9 * st$M, NODE[(st$ei - 1) %% 9 + 1], ENV[pmax(1, st$ei - 9 * st$M)])
  part[st$ei <= 9 * st$M & part != "storage"] <- "member"
  cat(sprintf("\n== %s: J %.9f, %d accepted, %d member evaluations\n", basename(f), x$J, nrow(st),
              x$counts$members))
  opening <- t0 < 0.05
  growth <- c(st$h[-1] / st$h[-nrow(st)], NA)
  inside <- c(iv[-1] == iv[-nrow(st)], FALSE) & !opening & since > 0.01
  for (w in c(FALSE, TRUE)) {
    k <- wet == w & !opening
    tab <- sort(table(part[k]), decreasing = TRUE)
    kk <- inside & wet == w & grepl("^soil", part)
    cat(sprintf("%-14s %5d steps | bound by %s\n", if (w) "rain intervals" else "dry intervals",
                sum(k), paste(sprintf("%s %.1f%%", names(tab), 100 * tab / sum(k)), collapse = ", ")))
    cat(sprintf("%-14s soil-bound inside an interval: %d | error ratio 10/50/90%%: %s | next step's growth: %s\n",
                "", sum(kk), paste(signif(quantile(st$er[kk], c(.1, .5, .9)), 2), collapse = " "),
                paste(signif(quantile(growth[kk], c(.1, .5, .9), na.rm = TRUE), 2), collapse = " ")))
  }
  per <- tabulate(iv, nbins = length(knots))
  first <- tabulate(iv[since < 1], nbins = length(knots))
  wet_iv <- rain_at(knots + DAY / 2) > 0
  for (w in c(FALSE, TRUE)) {
    k <- wet_iv == w
    cat(sprintf("%-14s %d intervals, %.1f steps each, %.1f in its first day\n",
                if (w) "rain intervals" else "dry intervals", sum(k), mean(per[k]), mean(first[k])))
  }
}
