# What set each accepted step of a TRAJ=1 run: the error component and its ratio, by
# what ended the step and by age band. A step ended on a knot with ratio r could have
# been about 0.9 r^(-1/5) times longer had the knot not stopped it.
source("/home/user/plant-dev/docs/measurements/schedule-search/round4/E/common.R")
nm <- commandArgs(TRUE)[1]; x <- readRDS(file.path(EO, "runs", paste0(nm, ".rds")))
tr <- x$traj; s <- x$setting; kn <- knots_of(s$regime, s$seed); nt <- sort(x$node_times)
st <- tr[!tr$intro & !is.na(tr$h), ]; st$start <- st$time - st$h
near <- function(a, b) { i <- findInterval(a, b); pmin(abs(a - b[pmax(i, 1)]), abs(a - b[pmin(i + 1, length(b))])) < 1e-9 }
st$cls <- ifelse(near(st$time, nt), "birth", ifelse(near(st$time, kn), "knot", ifelse(st$h > 0.999 * 15 / 365, "hmax", "ctrl")))
st$alive <- vapply(st$start, function(v) sum(nt <= v) + 1, 0)
st$band <- cut(st$start, c(0, 5, 10, 20, 25, 30, 33, 40), right = FALSE)
# State layout: per node 9 states (species block), then the environment (soil 5, accumulators).
n_env <- tail(tr$size, 1) - 9 * length(nt); cat("environment states:", n_env, "\n")
first_env <- st$size - n_env
st$comp <- ifelse(is.na(st$index), "none", ifelse(st$index > first_env, ifelse(st$index - first_env <= 5, "soil", "accum"), "node"))
cat("attempts:", x$attempts, "\n")
cat("component setting the step, rows share by class:\n"); print(round(100 * with(st, tapply(alive, list(cls, comp), sum)) / sum(st$alive), 1))
cat("\nmedian error ratio and step-growth room 0.9 r^-0.2 for knot-ended steps, by band:\n")
k <- st[st$cls == "knot", ]
print(do.call(rbind, lapply(split(k, k$band), function(d) c(n = nrow(d), rows_pct = round(100 * sum(d$alive) / sum(st$alive), 1),
  r_med = signif(median(d$ratio, na.rm = TRUE), 2), r_q25 = signif(quantile(d$ratio, .25, na.rm = TRUE), 2), r_q75 = signif(quantile(d$ratio, .75, na.rm = TRUE), 2),
  room_med = round(median(0.9 * d$ratio^-0.2, na.rm = TRUE), 2), soil = round(mean(d$comp == "soil"), 2)))))
cat("\nctrl steps by band: median ratio, h (d), component shares:\n")
k <- st[st$cls == "ctrl", ]
print(do.call(rbind, lapply(split(k, k$band), function(d) c(n = nrow(d), h_d = round(365 * median(d$h), 2), r_med = signif(median(d$ratio, na.rm = TRUE), 2),
  soil = round(mean(d$comp == "soil"), 2), node = round(mean(d$comp == "node"), 2), accum = round(mean(d$comp == "accum"), 2)))))
saveRDS(st, file.path(EO, paste0(nm, "_traj.rds")))
