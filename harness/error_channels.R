# Where a run's error in J travels, against a tighter run of the same stand, both
# kept by harness/ark_prototype.R with OUT and STATES:
# - the survival-weighted offspring's error split into a survival part, from the
#   members' cumulative mortality, and an output part, and when each accrues;
# - the survival part's largest contributions: the mortality difference created
#   over an interval times the offspring still to come, with that member's pool;
# - the ten oldest members' pools' relative error, near empty while refilling and
#   over half full.
#
#   PLANT_LIB=... RUN=ck_u108_1e-4.rds REF=ck_u108_1e-7.rds Rscript harness/error_channels.R
#
# RUN and REF name the OUT files; their STATES are the same names ending _states.rds.
local({
  here <- tryCatch(dirname(sys.frame(1)$ofile), error = function(e) "harness")
  source(file.path(here, "long_drought.R"))
})
states <- function(f) readRDS(sub("\\.rds$", "_states.rds", f))
A <- readRDS(Sys.getenv("RUN")); Sa <- states(Sys.getenv("RUN"))
B <- readRDS(Sys.getenv("REF")); Sb <- states(Sys.getenv("REF"))
p <- add_strategies(scm_base_parameters("TF24"), trait_matrix(LMA0, "lma"))
w <- B$by_node$weight * B$by_node$patch_density * p$strategies[[1]]$pars$S_D / B$J
common <- intersect(A$st$time, B$st$time)
ia <- match(common, A$st$time)
ib <- match(common, B$st$time)
# A member's component at one of the common times, for the members held there.
at <- function(S, i, comp) {
  y <- S[[i]]
  y[9 * (seq_len((length(y) - 10) %/% 9) - 1) + comp]
}
F_end <- at(Sb, length(Sb), 7)

# Over each interval F grows by e^-m times its output's increment, so the
# mortality difference's share is (e^-dm - 1) times the reference's increment.
parts <- matrix(0, length(common), 2)
created <- data.frame()
for (k in seq_along(common)[-1]) {
  M <- length(at(Sb, ib[k - 1], 2))
  m <- seq_len(M)
  dm0 <- at(Sa, ia[k - 1], 2) - at(Sb, ib[k - 1], 2)
  dm1 <- (at(Sa, ia[k], 2) - at(Sb, ib[k], 2))[m]
  dF_ref <- at(Sb, ib[k], 7)[m] - at(Sb, ib[k - 1], 7)
  dF_run <- at(Sa, ia[k], 7)[m] - at(Sa, ia[k - 1], 7)
  survival <- sum(w[m] * (exp(-(dm0 + dm1) / 2) - 1) * dF_ref)
  parts[k, ] <- c(survival, sum(w[m] * (dF_run - dF_ref)) - survival)
  gain <- -w[m] * (F_end[m] - at(Sb, ib[k], 7)[m]) * (dm1 - dm0)
  j <- which.max(abs(gain))
  created <- rbind(created, data.frame(t = common[k - 1], days = 365 * (common[k] - common[k - 1]),
    total = sum(gain), member = j, S0 = at(Sb, ib[k - 1], 6)[j], S1 = at(Sb, ib[k], 6)[j],
    dS0 = at(Sa, ia[k - 1], 6)[j] / at(Sb, ib[k - 1], 6)[j] - 1,
    dS1 = at(Sa, ia[k], 6)[j] / at(Sb, ib[k], 6)[j] - 1))
}
cat(sprintf("J %+.3e against the reference; offspring %+.3e = survival %+.3e + output %+.3e\n",
            A$J / B$J - 1, sum(parts), sum(parts[, 1]), sum(parts[, 2])))
marks <- c(5, 10, 12, 14, 16, 18, 20, 25, 30, 40)
upto <- function(v) sapply(marks, function(t) sum(v[common <= t]))
cat("accrued by t =", marks, "\n  survival:", sprintf("%+.1e", upto(parts[, 1])),
    "\n  output:  ", sprintf("%+.1e", upto(parts[, 2])), "\n")
cat("the survival part's largest contributions (its member's pool in the reference, and the run's relative difference):\n")
top <- created[order(-abs(created$total))[1:8], ]
for (i in seq_len(nrow(top))) with(top[i, ], cat(sprintf(
  "  t %.4f + %5.1f d: %+.2e, member %d, pool %.3g -> %.3g, difference %+.1e -> %+.1e\n",
  t, days, total, member, S0, S1, dS0, dS1)))

# The pools of the ten oldest members, by how full the reference's pool is.
near <- c()
full <- c()
for (j in 1:10) {
  Sr <- sapply(ib, function(i) at(Sb, i, 6)[j])
  Sr_next <- c(Sr[-1], NA)
  rel <- abs(sapply(ia, function(i) at(Sa, i, 6)[j]) / Sr - 1)
  top_j <- max(Sr, na.rm = TRUE)
  near <- c(near, rel[!is.na(Sr_next) & Sr < 0.02 * top_j & Sr_next > Sr])
  full <- c(full, rel[Sr > 0.5 * top_j])
}
q <- function(x) sprintf("median %.2e, 90%% %.2e", median(x, na.rm = TRUE), quantile(x, 0.9, na.rm = TRUE))
cat(sprintf("the ten oldest pools' relative error: below 2%% of their largest value and refilling %s; over half full %s\n",
            q(near), q(full)))
