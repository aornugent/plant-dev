# Where creation shuts, and what predicts it. A newborn's establishment
# probability in full light, along the soil chain alone and along a coupled
# run's soil, and coarser runs' own creation records, each against a reference
# run's creation record: which of its gaps each explains, and how far each
# opening is from the nearest predicted one.
#
#   PLANT_LIB=... Rscript harness/chain_creation.R chain.rds run.rds reference.rds \
#     [record.rds ...]
#
# chain.rds is harness/soil_chain.R's OUT, run.rds harness/ark_prototype.R's
# (its steps carry the soil layers at each step's end), and reference.rds and
# each record.rds harness/run_record.R's, all on one record.
local({
  here <- tryCatch(dirname(sys.frame(1)$ofile), error = function(e) "harness")
  source(file.path(here, "long_drought.R"))
})
args <- commandArgs(TRUE)
ch <- readRDS(args[1])
x <- readRDS(args[2])
ref <- readRDS(args[3])
stopifnot(ch$regime == ref$setting$regime)
DAY <- 1 / 365
p <- scm_base_parameters("TF24")
p$max_patch_lifetime <- LIFETIME
p <- add_strategies(p, trait_matrix(ref$setting$lma, "lma"))
ind <- TF24_Individual(p$strategies[[1]])
env <- mkenv(ref$setting$regime)
newborn <- function(theta) apply(theta, 1, function(th) {
  env$set_soil_water_state(th)
  ind$establishment_probability(env)
})

# Each series is a set of steps [start, end) carrying one value; it is open
# where the value is positive.
creation <- function(r) data.frame(start = r$stand$creation$start, end = r$stand$creation$end,
                                   value = r$stand$creation$rate)
soil <- as.matrix(x$st[, paste0("soil_", 1:5)])
series <- list(
  "chain alone, full light" = data.frame(start = ch$rows[, "t0"], end = ch$rows[, "t0"] + ch$rows[, "h"],
                                         value = newborn(ch$rows[, paste0("theta_", 1:5)])),
  "coupled soil, full light" = data.frame(start = c(0, x$st$time[-nrow(x$st)]), end = x$st$time,
                                          value = newborn(rbind(rep(0.214, 5), soil[-nrow(soil), ]))))
# A run's cost as its member-steps: each accepted step's members, scaled by its
# attempts over its accepted steps.
member_steps <- function(r) {
  a <- r$stand$attempts
  sum(as.numeric(findInterval(r$stand$times, sort(r$node_times)))) *
    (a[["accepted"]] + a[["rejected_inaccurate"]] + a[["rejected_thrown"]]) / a[["accepted"]]
}
cost <- c()
for (f in args[-(1:3)]) {
  r <- readRDS(f)
  k <- sprintf("%d nodes at %g", r$setting$nodes, r$setting$tol)
  series[[k]] <- creation(r)
  cost[k] <- member_steps(r)
}
gaps <- function(d) {
  r <- rle(d$value > 0)
  last <- cumsum(r$lengths)
  first <- last - r$lengths + 1
  shut <- which(!r$values)
  data.frame(from = d$start[first[shut]], to = d$end[last[shut]])
}
length_of <- function(g) sum(g$to - g$from)
covered <- function(g, by) {
  sum(vapply(seq_len(nrow(g)), function(i)
    sum(pmax(0, pmin(g$to[i], by$to) - pmax(g$from[i], by$from))), 0))
}
truth <- gaps(creation(ref))
opens <- truth$to[truth$to < LIFETIME]
cat(sprintf("== reference %s: %d nodes at %g, %d gaps, %.2f of %d years shut; the first from %.4f to %.4f; %d openings before t = 10\n",
            basename(args[3]), ref$setting$nodes, ref$setting$tol, nrow(truth), length_of(truth), LIFETIME,
            truth$from[1], truth$to[1], sum(opens < 10)))
for (k in names(series)) {
  g <- gaps(series[[k]])
  if (nrow(g) == 0) {
    cat(sprintf("%-26s no gaps\n", k))
    next
  }
  near <- vapply(opens, function(t) min(abs(g$to - t)), 0) / DAY
  cat(sprintf("%-26s %3d gaps, %.2f years shut; the reference's gap time inside its gaps %.0f%%, its own inside the reference's %.0f%%; first gap %.4f-%.4f%s\n",
              k, nrow(g), length_of(g), 100 * covered(truth, g) / length_of(truth),
              100 * covered(g, truth) / length_of(g), g$from[1], g$to[1],
              if (is.na(cost[k])) "" else sprintf("; %.3g member-steps", cost[k])))
  cat(sprintf("%-26s each opening to its nearest, days, 10/50/90%%: %s; within a day %.0f%%; before t = 10: %s\n", "",
              paste(signif(quantile(near, c(.1, .5, .9)), 2), collapse = " "), 100 * mean(near <= 1),
              paste(sprintf("%.1f", near[opens < 10]), collapse = " ")))
}
