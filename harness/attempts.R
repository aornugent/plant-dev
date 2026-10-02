# Where the driver's rejected attempts fall, from harness/ark_prototype.R's
# ATTEMPT_LOG and OUT files: by the days since the record's last knot, by the
# component whose error rejected them, and for the first attempt after a knot by
# how the rain changes over the day it opens. The record's interpolant passes
# through each day's value at the knot that opens the day and reaches the next
# day's value at the day's end. Also each attempt's size against the size
# accepted from the same start.
#
#   Rscript harness/attempts.R run.rds attempts.rds [run2.rds attempts2.rds ...]
#
# A run saved before the driver kept its record's rain and knots is long
# drought's.
here <- tryCatch(dirname(sys.frame(1)$ofile), error = function(e) "harness")
ld <- readRDS(file.path(here, "..", "docs", "measurements", "spot-check", "ld_3e-5.rds"))
DAY <- 1 / 365
NODE <- c("height", "mortality", "fecundity", "area_heartwood", "mass_heartwood",
          "storage", "offspring", "log_density", "mass")
ENV <- c(paste0("soil_", 1:5), paste0("accumulator_", 1:5))

describe <- function(run, a) {
  knots <- sort(unique(if (is.null(run$knots)) ld$knots else run$knots))
  rain <- if (is.null(run$rain)) ld$rain else run$rain
  rain_at <- function(t) rain[pmin(pmax(floor(t / DAY + 1e-9) + 1, 1), length(rain))]
  st <- run$st
  M <- st$M[match(round(a$t0, 12), round(st$time - st$h, 12))]
  kind <- ifelse(is.na(a$index), "thrown",
                 ifelse(a$index <= 9 * M, NODE[(a$index - 1) %% 9 + 1], ENV[pmax(1, a$index - 9 * M)]))
  part <- ifelse(grepl("^soil_", kind), "soil", ifelse(kind %in% c("storage", "thrown"), kind, "member"))
  i <- findInterval(a$t0 + 1e-12, knots)
  since <- ifelse(i > 0, a$t0 - knots[pmax(i, 1)], a$t0) / DAY
  band <- cut(since, c(-1, 0.001, 1, 10, 1e5), labels = c("on a knot", "within a day", "1-10 days", "over 10 days"))
  before <- rain_at(a$t0 + 0.5 * DAY); after <- rain_at(a$t0 + 1.5 * DAY)
  change <- ifelse(before == 0 & after > 0, "starts", ifelse(before > 0 & after == 0, "stops",
                   ifelse(after > before, "rises", ifelse(after < before, "falls", "flat"))))
  first_at_knot <- band == "on a knot" & a$t0 > 0 & !duplicated(round(a$t0, 12))
  data.frame(rejected = a$rejected == 1, band, part, change, first_at_knot, t0 = round(a$t0, 12), h = a$h)
}

files <- commandArgs(TRUE)
for (i in seq(1, length(files), by = 2)) {
  run <- readRDS(files[i]); d <- describe(run, readRDS(files[i + 1]))
  cat(sprintf("\n== %s: J %.9f, %d accepted, %d rejected or thrown (%.1f%% of attempts), %d member evaluations\n",
              basename(files[i]), run$J, sum(!d$rejected), sum(d$rejected), 100 * mean(d$rejected),
              run$counts$members))
  by_band <- table(d$band, d$rejected)
  print(data.frame(accepted = by_band[, "FALSE"], rejected = by_band[, "TRUE"],
                   share_of_rejected = round(by_band[, "TRUE"] / sum(d$rejected), 3)))
  cat("rejected by component, within a day of a knot / over 10 days after one:\n")
  print(rbind(near = table(factor(d$part[d$rejected & d$band %in% c("on a knot", "within a day")],
                                  c("soil", "storage", "member", "thrown"))),
              far = table(factor(d$part[d$rejected & d$band == "over 10 days"], c("soil", "storage", "member", "thrown")))))
  f <- d$first_at_knot
  cat("first attempts at a knot rejected, by the change:",
      paste(sprintf("%s %.2f (%d)", names(tapply(d$rejected[f], d$change[f], mean)),
                    tapply(d$rejected[f], d$change[f], mean), tapply(d$rejected[f], d$change[f], length)), collapse = ", "), "\n")
  acc <- tapply(d$h[!d$rejected], d$t0[!d$rejected], function(v) v[1])
  r <- d$h[d$rejected] / acc[as.character(d$t0[d$rejected])]
  k <- d$rejected & f
  cat("a rejected attempt over the size accepted from its start, 10/50/90%:",
      paste(signif(quantile(r, c(.1, .5, .9), na.rm = TRUE), 3), collapse = " "),
      "| rejected first attempts at a knot, days:", paste(signif(quantile(d$h[k] / DAY, c(.1, .5, .9)), 3), collapse = " "),
      "| accepted from there:", paste(signif(quantile(acc[as.character(d$t0[k])] / DAY, c(.1, .5, .9), na.rm = TRUE), 3), collapse = " "), "\n")
}
